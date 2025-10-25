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
            print("✅ Export command completed, waiting for files to appear...")
            
            // Give Capture One a moment to start exporting
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // The monitor will detect new files and upload them automatically
            print("✅ Monitoring for exported files...")
            
            // Check after 10 seconds if any files appeared
            try await Task.sleep(nanoseconds: 10_000_000_000)
            
            if processedFiles.isEmpty {
                print("⚠️ No files appeared in expected folder")
                isExporting = false
                showRecipePathError = true // Show recreate recipe prompt
                return // Don't throw - let the UI handle it
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
    
    /// Clean the export folder of any old files
    private func cleanExportFolder(_ folder: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        
        for file in contents {
            try fileManager.removeItem(at: file)
            print("🗑️ Cleaned old file: \(file.lastPathComponent)")
        }
        
        processedFiles.removeAll()
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
        
        // Skip hidden files and duplicates
        guard !fileName.hasPrefix("."),
              !processedFiles.contains(fileName) else {
            return
        }
        
        // Check if it's an image file
        let imageExtensions = ["jpg", "jpeg", "png", "tif", "tiff", "heic", "dng", "cr2", "nef", "arw"]
        guard imageExtensions.contains(path.pathExtension.lowercased()) else {
            print("⏭️ Skipping non-image file: \(fileName)")
            return
        }
        
        processedFiles.insert(fileName)
        
        print("📸 New export detected: \(fileName)")
        exportProgress = "Uploading \(fileName)..."
        
        // Wait a bit to ensure file is fully written
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
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
        
        // Check if we're done with all files
        await checkIfExportComplete()
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
    
    /// Check if export and upload process is complete
    private func checkIfExportComplete() async {
        // Wait a bit to see if more files are coming
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Check export folder
        if let exportFolder = try? CaptureOneScriptBridge.getExportFolder() {
            let fileManager = FileManager.default
            if let contents = try? fileManager.contentsOfDirectory(at: exportFolder, includingPropertiesForKeys: nil),
               contents.filter({ !$0.lastPathComponent.hasPrefix(".") }).isEmpty {
                // All files processed
                isExporting = false
                exportProgress = "Upload complete!"
                print("✅ All exports uploaded and cleaned up")
                
                // Clear progress message after a delay
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    exportProgress = ""
                }
                
                // Stop monitoring
                exportMonitor?.stopMonitoring()
                exportMonitor = nil
            }
        }
    }
}

