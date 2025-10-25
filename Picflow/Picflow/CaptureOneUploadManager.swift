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
    private var processedFiles: Set<String> = []
    private var expectedExportFolder: URL?
    private var lastFileSeenTime: Date = Date()
    private var completionCheckTask: Task<Void, Never>?
    
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
        processedFiles.removeAll()
        lastFileSeenTime = Date()
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
            
            if processedFiles.isEmpty {
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
              !processedFiles.contains(fileName),
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
        
        print("📸 Complete file detected: \(fileName)")
        
        // No need to wait for stability - if it doesn't have .tmp extension, Capture One already finished writing it!
        processedFiles.insert(fileName)
        lastFileSeenTime = Date() // Update last seen time
        
        exportProgress = "Uploading \(processedFiles.count) files..."
        
        // Upload the file
        do {
            try await uploader.upload(fileURL: path)
            print("✅ Uploaded: \(fileName)")
            
            // Delete the file after successful upload
            try FileManager.default.removeItem(at: path)
            print("🗑️ Deleted: \(fileName)")
            
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
    /// Marks export complete when no new files appear for 5 seconds
    private func startCompletionChecker() {
        completionCheckTask?.cancel()
        
        completionCheckTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every 1 second
                
                // If no new files for 5 seconds, we're done
                let timeSinceLastFile = Date().timeIntervalSince(lastFileSeenTime)
                
                if timeSinceLastFile >= 5.0 && !processedFiles.isEmpty {
                    print("✅ No new files for 5 seconds - export complete")
                    print("📊 Total files processed: \(processedFiles.count)")
                    
                    isExporting = false
                    exportProgress = "Upload complete!"
                    
                    // Clear progress message after a delay
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        if !isExporting { // Only clear if still not exporting
                            exportProgress = ""
                        }
                    }
                    
                    // Stop monitoring
                    exportMonitor?.stopMonitoring()
                    exportMonitor = nil
                    
                    break // Exit the loop
                }
            }
        }
    }
}

