//
//  CaptureOneUploadManager.swift
//  Picflow
//
//  Manages the workflow of exporting from Capture One and uploading to Picflow
//

import Foundation
import AppKit

@MainActor
class CaptureOneUploadManager: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var isUploading: Bool = false
    @Published var exportProgress: String = ""
    @Published var error: String?
    @Published var showRecipePathError: Bool = false // Show "Recreate Recipe" prompt
    
    private let scriptBridge = CaptureOneScriptBridge()
    private var exportMonitor: FolderMonitor?
    private var detectedFiles: Set<String> = [] // Files we've seen
    private var uploadedFiles: Set<String> = [] // Files successfully uploaded
    private var expectedExportFolder: URL?
    private var lastFileDetectedTime: Date = Date()
    private var completionCheckTask: Task<Void, Never>?
    private let uploadQueue = UploadQueue(maxConcurrent: 3) // Upload 3 files at a time
    
    // MARK: - Computed Properties for UI
    
    /// Upload state for the generic progress view
    var uploadState: UploadState {
        if let error = error, !error.isEmpty {
            return .failed
        } else if !isExporting && !exportProgress.isEmpty && exportProgress.contains("complete") {
            return .completed
        } else if isExporting {
            return .uploading
        } else {
            return .idle
        }
    }
    
    /// Status description for the generic progress view
    var statusDescription: String {
        // Show error if present
        if let error = error, !error.isEmpty {
            return error
        }
        
        // Show progress message
        if !exportProgress.isEmpty {
            return exportProgress
        }
        
        return "Processing..."
    }
    
    // MARK: - Export and Upload
    
    /// Start the export and upload process
    func exportAndUpload(uploader: Uploader) async {
        guard !isExporting else {
            print("⚠️ Export already in progress")
            return
        }
        
        isExporting = true
        exportProgress = "Preparing export..."
        error = nil
        showRecipePathError = false
        detectedFiles.removeAll()
        uploadedFiles.removeAll()
        lastFileDetectedTime = Date()
        completionCheckTask?.cancel()
        
        do {
            // Get export folder
            let exportFolder = try CaptureOneScriptBridge.getExportFolder()
            expectedExportFolder = exportFolder
            print("📁 Export folder: \(exportFolder.path)")
            
            // Clear any old files in the export folder
            try cleanExportFolder(exportFolder)
            
            // Start monitoring the export folder
            startMonitoring(exportFolder: exportFolder, uploader: uploader)
            
            exportProgress = "Exporting variants..."
            print("🎬 Starting export...")
            
            // Trigger export with timeout (recipe will be created automatically if needed)
            do {
                try await withTimeout(seconds: 30) {
                    _ = try await self.scriptBridge.exportSelectedVariants(recipeName: "Picflow Upload", outputFolder: exportFolder)
                }
            } catch is TimeoutError {
                throw CaptureOneScriptBridge.CaptureOneError.scriptExecutionFailed("Export timed out after 30 seconds. Please check Capture One.")
            }
            
            exportProgress = "Waiting for files..."
            print("✅ Export command completed, monitoring for files...")
            
            // Start auto-completion checker
            startCompletionChecker()
            
            // Wait a bit to see if files appear
            try await Task.sleep(nanoseconds: 10_000_000_000)
            
            if detectedFiles.isEmpty {
                print("⚠️ No files appeared in expected folder after 10 seconds")
                isExporting = false
                showRecipePathError = true
                completionCheckTask?.cancel()
                return
            }
            
        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Export failed: \(errorMessage)"
            print("❌ Export error: \(errorMessage)")
            isExporting = false
            exportMonitor?.stopMonitoring()
            exportMonitor = nil
        }
    }
    
    // MARK: - Timeout Helper
    
    struct TimeoutError: Error {}
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError()
            }
            
            // Wait for first to complete
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Clean the export folder of any old files (including .tmp files from failed exports)
    private func cleanExportFolder(_ folder: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        
        for file in contents {
            // Skip hidden files
            guard !file.lastPathComponent.hasPrefix(".") else { continue }
            
            try fileManager.removeItem(at: file)
            print("🗑️ Cleaned old file: \(file.lastPathComponent)")
        }
    }
    
    /// Start monitoring the export folder for new files
    private func startMonitoring(exportFolder: URL, uploader: Uploader) {
        exportMonitor?.stopMonitoring()
        
        let monitor = FolderMonitor(folderURL: exportFolder) { [weak self] path, event in
            Task { @MainActor in
                await self?.handleFileEvent(path: path, event: event, uploader: uploader)
            }
        }
        monitor.startMonitoring()
        
        exportMonitor = monitor
    }
    
    /// Handle file system events
    private func handleFileEvent(path: URL, event: FileEvent, uploader: Uploader) async {
        // Only process new files
        guard event == .added else { return }
        
        let fileName = path.lastPathComponent
        
        // Skip hidden files, duplicates, and temp files
        guard !fileName.hasPrefix("."),
              !detectedFiles.contains(fileName),
              !fileName.hasSuffix(".tmp") else { // Ignore .tmp files - Capture One uses these during export
            if fileName.hasSuffix(".tmp") {
                print("⏭️ Skipping temp file (still being written): \(fileName)")
            }
            return
        }
        
        // Check if it's an image file
        let imageExtensions = ["jpg", "jpeg", "png", "tif", "tiff", "heic", "dng", "cr2", "nef", "arw"]
        guard imageExtensions.contains(path.pathExtension.lowercased()) else {
            print("⏭️ Skipping non-image file: \(fileName)")
            return
        }
        
        print("📸 File detected: \(fileName)")
        
        // Mark as detected
        detectedFiles.insert(fileName)
        lastFileDetectedTime = Date() // Update last detection time
        
        // Queue upload (runs concurrently)
        await uploadQueue.addUpload { [weak self] in
            guard let self = self else { return }
            
            await self.uploadFile(path: path, fileName: fileName, uploader: uploader)
        }
    }
    
    /// Upload a single file
    private func uploadFile(path: URL, fileName: String, uploader: Uploader) async {
        // Update progress
        let uploaded = uploadedFiles.count
        let detected = detectedFiles.count
        exportProgress = "Uploading \(uploaded + 1) of \(detected)..."
        
        // Upload the file
        do {
            try await uploader.upload(fileURL: path)
            print("✅ Uploaded: \(fileName)")
            
            // Delete the file after successful upload
            try FileManager.default.removeItem(at: path)
            print("🗑️ Deleted: \(fileName)")
            
            // Mark as uploaded
            uploadedFiles.insert(fileName)
            
        } catch {
            self.error = "Upload failed for \(fileName): \(error.localizedDescription)"
            print("❌ Upload failed: \(fileName) - \(error)")
        }
    }
    
    /// Recreate the recipe with the correct output location (deletes old one first)
    func recreateRecipe() async {
        guard let exportFolder = expectedExportFolder else {
            error = "Export folder not set"
            return
        }
        
        showRecipePathError = false
        error = nil
        exportProgress = "Recreating recipe..."
        
        do {
            // Force recreate the recipe with correct output location
            try await scriptBridge.forceRecreateRecipe(recipeName: "Picflow Upload", outputFolder: exportFolder)
            exportProgress = "Recipe recreated! Try uploading again."
            
            // Clear message after delay
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                exportProgress = ""
            }
        } catch {
            self.error = "Failed to recreate recipe: \(error.localizedDescription)"
            print("❌ Recipe recreation failed: \(error)")
        }
    }
    
    /// Start background task that checks for completion
    /// Marks export complete when: (no new files for 5s) AND (all detected files uploaded)
    private func startCompletionChecker() {
        completionCheckTask?.cancel()
        
        completionCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                
                let detected = detectedFiles.count
                let uploaded = uploadedFiles.count
                let timeSinceLastDetection = Date().timeIntervalSince(lastFileDetectedTime)
                
                // Completion conditions:
                // 1. At least one file detected
                // 2. No new files detected for 5 seconds
                // 3. All detected files have been uploaded
                if detected > 0 && timeSinceLastDetection >= 5.0 && uploaded == detected {
                    print("✅ Export complete!")
                    print("📊 Detected: \(detected), Uploaded: \(uploaded)")
                    
                    isExporting = false
                    exportProgress = "Upload complete!"
                    
                    // Clear progress message after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if !isExporting {
                            exportProgress = ""
                        }
                    }
                    
                    // Stop monitoring
                    exportMonitor?.stopMonitoring()
                    exportMonitor = nil
                    
                    break
                } else if detected > 0 {
                    // Still working - log progress
                    print("📊 Progress: \(uploaded)/\(detected) uploaded, waiting for completion...")
                }
            }
        }
    }
}

// MARK: - Upload Queue

/// Manages concurrent uploads with a limit
actor UploadQueue {
    private let maxConcurrent: Int
    private var activeTasks: Int = 0
    private var waitingTasks: [() async -> Void] = []
    
    init(maxConcurrent: Int) {
        self.maxConcurrent = maxConcurrent
    }
    
    /// Add an upload to the queue
    func addUpload(_ task: @escaping () async -> Void) async {
        // If we have capacity, run immediately
        if activeTasks < maxConcurrent {
            activeTasks += 1
            await runTask(task)
        } else {
            // Otherwise queue it
            waitingTasks.append(task)
        }
    }
    
    /// Run a task and process next in queue
    private func runTask(_ task: @escaping () async -> Void) async {
        await task()
        
        activeTasks -= 1
        
        // Process next task if available
        if !waitingTasks.isEmpty {
            let nextTask = waitingTasks.removeFirst()
            activeTasks += 1
            
            // Run next task without awaiting (fire and forget)
            Task {
                await self.runTask(nextTask)
            }
        }
    }
}
