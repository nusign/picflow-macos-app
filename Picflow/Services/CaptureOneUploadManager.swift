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
    @Published var exportProgress: String = ""
    @Published var error: String?
    
    private let scriptBridge = CaptureOneScriptBridge()
    private var exportMonitor: FolderMonitor?
    private var detectedFiles: Set<String> = [] // Files we've detected in folder
    private var expectedExportFolder: URL?
    private var expectedFileCount: Int = 0 // Count from Capture One
    private var lastFileDetectedTime: Date = Date()
    private var completionCheckTask: Task<Void, Never>?
    
    // MARK: - Upload Workflows
    
    /// Upload original RAW files without export
    func uploadOriginalFiles(uploader: Uploader) async {
        guard !isExporting else {
            print("⚠️ Upload already in progress")
            return
        }
        
        isExporting = true
        exportProgress = "Getting file paths..."
        error = nil
        
        do {
            // Get file paths of selected variants
            let filePaths = try await scriptBridge.getSelectedVariantPaths()
            
            guard !filePaths.isEmpty else {
                error = "No files found for selected variants"
                isExporting = false
                return
            }
            
            print("📸 Uploading \(filePaths.count) original files")
            exportProgress = ""
            
            // Queue files for upload using the standard uploader
            // This gives us full progress tracking (speed, time remaining, etc.)
            uploader.queueFiles(filePaths)
            
            // Wait for uploads to complete
            while uploader.isUploading {
                try await Task.sleep(nanoseconds: 500_000_000) // Check every 0.5s
            }
            
            isExporting = false
            
        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Failed to get file paths: \(errorMessage)"
            print("❌ Get file paths error: \(errorMessage)")
            
            // Show error alert to user
            ErrorAlertManager.shared.showCaptureOneError(
                message: "Failed to get file paths from Capture One. Make sure variants are selected.",
                error: error
            )
            
            isExporting = false
        }
    }
    
    /// Start the export and upload process
    func exportAndUpload(uploader: Uploader) async {
        guard !isExporting else {
            print("⚠️ Export already in progress")
            return
        }
        
        isExporting = true
        exportProgress = "Preparing export..."
        error = nil
        detectedFiles.removeAll()
        expectedFileCount = 0
        lastFileDetectedTime = Date()
        completionCheckTask?.cancel()
        
        do {
            // Get export folder
            let exportFolder = try CaptureOneScriptBridge.getExportFolder()
            expectedExportFolder = exportFolder
            print("📁 Export folder: \(exportFolder.path)")
            
            // Clear any old files in the export folder
            // Note: This intentionally deletes files from manual exports or previous failed uploads
            // The export folder is app-controlled and should only contain files from current export
            try cleanExportFolder(exportFolder)
            
            // Start monitoring the export folder
            startMonitoring(exportFolder: exportFolder, uploader: uploader)
            
            exportProgress = "Exporting variants..."
            print("🎬 Starting export...")
            
            // Trigger export with timeout (recipe will be created automatically if needed)
            let exportResult: (folder: URL, count: Int)
            do {
                exportResult = try await withTimeout(seconds: 30) {
                    try await self.scriptBridge.exportSelectedVariants(recipeName: "Picflow Upload", outputFolder: exportFolder)
                }
            } catch is TimeoutError {
                throw CaptureOneScriptBridge.CaptureOneError.scriptExecutionFailed("Export timed out after 30 seconds. Please check Capture One.")
            }
            
            // Store expected count for completion detection
            expectedFileCount = exportResult.count
            print("✅ Export command completed, expecting \(expectedFileCount) files...")
            exportProgress = ""
            
            // Start auto-completion checker
            startCompletionChecker(uploader: uploader)
            
            // Wait a bit to see if files appear
            try await Task.sleep(nanoseconds: 10_000_000_000)
            
            if detectedFiles.isEmpty {
                print("⚠️ No files appeared in expected folder after 10 seconds")
                print("📁 Expected folder: \(exportFolder.path)")
                
                // Reset to idle state BEFORE showing alert (since alert blocks)
                isExporting = false
                exportProgress = ""
                self.error = nil
                completionCheckTask?.cancel()
                exportMonitor?.stopMonitoring()
                exportMonitor = nil
                
                // Show alert with action buttons
                let errorMsg = """
                Your exports did not appear in the expected folder. This usually means the location is wrong.
                
                Click "Recreate Recipe", or check manually in Capture One.
                """
                
                ErrorAlertManager.shared.showAlertWithAction(
                    title: "No Files Detected",
                    message: errorMsg,
                    primaryButton: "Recreate Recipe",
                    secondaryButton: "Cancel"
                ) { [weak self] in
                    await self?.recreateRecipe()
                }
                
                return
            }
            
        } catch {
            let errorMessage = error.localizedDescription
            self.error = "Export failed: \(errorMessage)"
            print("❌ Export error: \(errorMessage)")
            
            // Show error alert to user
            ErrorAlertManager.shared.showCaptureOneError(
                message: "Export from Capture One failed. \(errorMessage)",
                error: error
            )
            
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
        
        // Queue the file through the standard uploader
        // This gives us full progress tracking (speed, time remaining, progress bar)
        uploader.queueFiles([path])
        
        // Delete the file after it's been queued
        // (the uploader reads it into memory/streams it, so we can delete the temp export)
        Task {
            // Wait a bit to ensure file is fully written
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            // Delete after upload completes (check periodically)
            while uploader.uploadQueue.contains(path) {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // File is uploaded, delete it
            try? FileManager.default.removeItem(at: path)
            print("🗑️ Deleted: \(fileName)")
        }
    }
    
    /// Recreate the recipe with the correct output location (deletes old one first)
    func recreateRecipe() async {
        guard let exportFolder = expectedExportFolder else {
            error = "Export folder not set"
            return
        }
        
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
            
            // Show error alert to user
            ErrorAlertManager.shared.showCaptureOneError(
                message: "Failed to recreate Capture One recipe. Please check Capture One settings.",
                error: error
            )
        }
    }
    
    /// Start background task that checks for completion
    /// Marks export complete when: all expected files have been detected AND uploaded
    private func startCompletionChecker(uploader: Uploader) {
        completionCheckTask?.cancel()
        
        completionCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                
                let detected = detectedFiles.count
                let timeSinceLastDetection = Date().timeIntervalSince(lastFileDetectedTime)
                
                // Completion conditions:
                // 1. All expected files have been detected (or 5s timeout)
                // 2. Uploader has finished uploading everything
                let allFilesDetected = detected >= expectedFileCount || (detected > 0 && timeSinceLastDetection >= 5.0)
                let uploadsComplete = !uploader.isUploading
                
                if allFilesDetected && uploadsComplete && detected > 0 {
                    print("✅ Export and upload complete!")
                    print("📊 Expected: \(expectedFileCount), Detected: \(detected)")
                    
                    isExporting = false
                    exportProgress = ""
                    
                    // Stop monitoring
                    exportMonitor?.stopMonitoring()
                    exportMonitor = nil
                    
                    break
                }
            }
        }
    }
}
