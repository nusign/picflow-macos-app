//
//  FolderMonitoringManager.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  Enhanced for live folder monitoring with:
//  - File stability check before upload
//  - Duplicate prevention
//  - Upload counter
//  - Retry logic

import Foundation
import UserNotifications

@MainActor
class FolderMonitoringManager: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var selectedFolder: URL?
    @Published private(set) var isWatching: Bool = false
    @Published private(set) var uploadState: UploadState = .idle
    @Published private(set) var statusDescription: String = "Waiting for new files..."
    @Published private(set) var totalUploaded: Int = 0
    
    // MARK: - Private Properties
    
    private var monitor: FolderMonitor?
    private let uploader: Uploader
    private var uploadedFiles = Set<String>() // Track uploaded filenames
    private var processingFiles = Set<String>() // Files currently being processed
    private var stabilityTasks: [String: Task<Void, Never>] = [:]
    private var retryAttempts: [String: Int] = [:]
    private let maxRetries = 3
    private let retryDelay: UInt64 = 2_000_000_000 // 2 seconds
    
    init(uploader: Uploader) {
        self.uploader = uploader
    }
    
    // MARK: - Public Methods
    
    /// Select a folder and start watching
    func selectFolder(_ url: URL) {
        print("📂 Live folder selected: \(url.path)")
        
        // Stop any existing monitoring first
        stopMonitoringInternal()
        
        // Set new folder and start watching
        selectedFolder = url
        startMonitoring(url)
    }
    
    func startMonitoring(_ url: URL) {
        guard !isWatching else {
            print("⚠️ Already watching")
            return
        }
        
        print("👁️ Starting to watch: \(url.path)")
        selectedFolder = url
        
        monitor = FolderMonitor(folderURL: url) { [weak self] fileURL, eventType in
            guard let self = self else { return }
            
            // Only handle NEW files (added events)
            guard eventType == .added else { return }
            
            // Ignore system files
            let filename = fileURL.lastPathComponent
            guard !filename.hasPrefix(".") else { return }
            
            // Handle the new file
            self.handleNewFile(fileURL)
        }
        monitor?.startMonitoring()
        isWatching = true
        uploadState = .idle
        statusDescription = "Waiting for new files..."
    }
    
    /// Stop monitoring and reset all state (called when toggle is turned off)
    func stopMonitoring() {
        print("🛑 Stopping live folder monitoring")
        stopMonitoringInternal()
        
        // Full reset when toggle is turned off
        selectedFolder = nil
        totalUploaded = 0
        uploadedFiles.removeAll()
        processingFiles.removeAll()
        retryAttempts.removeAll()
        uploadState = .idle
        statusDescription = "Waiting for new files..."
    }
    
    /// Internal method to stop monitoring without resetting folder selection
    private func stopMonitoringInternal() {
        // Cancel all ongoing operations
        stabilityTasks.values.forEach { $0.cancel() }
        stabilityTasks.removeAll()
        
        // Stop monitor
        monitor?.stopMonitoring()
        monitor = nil
        isWatching = false
    }
    
    // MARK: - Private Methods
    
    /// Handle a new file detected in the folder
    private func handleNewFile(_ fileURL: URL) {
        let filename = fileURL.lastPathComponent
        
        // Skip directories
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            print("⏭️ Skipping directory: \(filename)")
            return
        }
        
        // Skip if already uploaded
        guard !uploadedFiles.contains(filename) else {
            print("⏭️ Skipping already uploaded file: \(filename)")
            return
        }
        
        // Skip if already being processed
        guard !processingFiles.contains(filename) else {
            print("⏭️ Already processing: \(filename)")
            return
        }
        
        print("🆕 New file detected: \(filename)")
        
        // Mark as processing
        processingFiles.insert(filename)
        
        // Start stability check
        let task = Task {
            await checkStabilityAndUpload(fileURL)
        }
        
        stabilityTasks[filename] = task
    }
    
    /// Check if file is stable (not being written) then upload
    private func checkStabilityAndUpload(_ fileURL: URL) async {
        let filename = fileURL.lastPathComponent
        
        // Update state
        await MainActor.run {
            statusDescription = "Checking \(filename)..."
        }
        
        print("⏳ Checking stability for: \(filename)")
        
        // Wait for file to stabilize
        guard await isFileStable(fileURL) else {
            print("⚠️ File disappeared or became unstable: \(filename)")
            await cleanupFile(filename)
            return
        }
        
        print("✅ File is stable: \(filename)")
        
        // Upload the file
        await uploadFile(fileURL)
    }
    
    /// Check if a file is stable (size unchanged for 2 seconds)
    private func isFileStable(_ fileURL: URL) async -> Bool {
        do {
            // Initial size check
            let attributes1 = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size1 = attributes1[.size] as? Int64 else {
                return false
            }
            
            // Wait 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Check if file still exists
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return false
            }
            
            // Second size check
            let attributes2 = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            guard let size2 = attributes2[.size] as? Int64 else {
                return false
            }
            
            // File is stable if sizes match
            return size1 == size2
            
        } catch {
            print("⚠️ Error checking file stability: \(error)")
            return false
        }
    }
    
    /// Upload a file with retry logic
    private func uploadFile(_ fileURL: URL) async {
        let filename = fileURL.lastPathComponent
        
        // Update state
        await MainActor.run {
            uploadState = .uploading
            statusDescription = "Uploading \(filename)..."
        }
        
        print("⬆️ Uploading: \(filename)")
        
        do {
            try await uploader.upload(fileURL: fileURL)
            
            // Success!
            print("✅ Upload completed: \(filename)")
            
            await MainActor.run {
                uploadState = .completed
                statusDescription = "Uploaded \(filename)"
                totalUploaded += 1
                uploadedFiles.insert(filename)
                retryAttempts.removeValue(forKey: filename)
            }
            
            // Reset to idle after 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if uploadState == .completed {
                    uploadState = .idle
                    statusDescription = "Waiting for new files..."
                }
            }
            
            await cleanupFile(filename)
            
        } catch {
            print("❌ Upload failed: \(filename) - \(error)")
            
            // Handle retry logic
            let attempts = await MainActor.run {
                let current = retryAttempts[filename] ?? 0
                retryAttempts[filename] = current + 1
                return current + 1
            }
            
            if attempts < maxRetries {
                print("🔄 Retry \(attempts)/\(maxRetries) for: \(filename)")
                
                await MainActor.run {
                    uploadState = .failed
                    statusDescription = "Retrying \(filename)... (\(attempts)/\(maxRetries))"
                }
                
                // Wait before retry
                try? await Task.sleep(nanoseconds: retryDelay)
                
                // Retry upload
                await uploadFile(fileURL)
                
            } else {
                print("💔 Max retries reached for: \(filename)")
                
                await MainActor.run {
                    uploadState = .failed
                    statusDescription = "Failed to upload \(filename)"
                    
                    // Show error alert to user after max retries
                    ErrorAlertManager.shared.showFolderMonitoringError(
                        message: "Failed to upload \(filename) from live folder after \(maxRetries) attempts. The file will be skipped.",
                        error: error
                    )
                }
                
                // Stay in error state for 5 seconds
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                
                await MainActor.run {
                    if uploadState == .failed {
                        uploadState = .idle
                        statusDescription = "Waiting for new files..."
                    }
                }
                
                await cleanupFile(filename)
            }
        }
    }
    
    /// Clean up tracking for a file
    private func cleanupFile(_ filename: String) async {
        stabilityTasks.removeValue(forKey: filename)
        processingFiles.remove(filename)
    }
    
    // MARK: - Helper Properties
    
    var folderName: String? {
        selectedFolder?.lastPathComponent
    }
    
    var folderDisplayPath: String? {
        guard let folder = selectedFolder else { return nil }
        
        // Get the path relative to home directory for cleaner display
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        if folder.path.hasPrefix(homeDir.path) {
            let relativePath = String(folder.path.dropFirst(homeDir.path.count))
            return "~\(relativePath)"
        }
        
        return folder.path
    }
    
    var isUploading: Bool {
        uploadState == .uploading
    }
    
    /// Expose uploader's progress for UI (0.0 to 1.0)
    var uploadProgress: Double {
        uploader.uploadProgress
    }
} 
