//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onBack: () -> Void
    @State private var isDragging = false
    @State private var isLiveModeEnabled = false
    
    // Access Capture One upload manager for unified visibility logic
    @StateObject private var captureOneMonitor = CaptureOneMonitor()
    @StateObject private var captureOneUploadManager = CaptureOneUploadManager()
    
    // Live folder monitoring
    @StateObject private var folderMonitoringManager: FolderMonitoringManager
    
    // MARK: - Initialization
    
    init(uploader: Uploader, authenticator: Authenticator, onBack: @escaping () -> Void) {
        self.uploader = uploader
        self.authenticator = authenticator
        self.onBack = onBack
        
        // Initialize folder monitoring manager
        _folderMonitoringManager = StateObject(wrappedValue: FolderMonitoringManager(uploader: uploader))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text(uploader.selectedGallery?.displayName ?? "Gallery")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
            
            // Content Area (back button, toggle, and main content)
            VStack(spacing: 16) {
                // Back Button and Live Toggle
                HStack {
                    BackButton(action: onBack)
                    
                    Spacer()
                    
                    // Live Mode Toggle
                    Toggle("Live", isOn: $isLiveModeEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: isLiveModeEnabled) { _, newValue in
                            handleLiveModeToggle(newValue)
                        }
                }
                
                // Main Content Area (fills available vertical space)
                if isLiveModeEnabled {
                    LiveFolderView(folderManager: folderMonitoringManager)
                        .frame(maxHeight: .infinity)
                } else {
                    DropAreaView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                        .frame(maxHeight: .infinity)
                }
            }
            
            // Status Components (Upload progress or Capture One Integration)
            if shouldShowStatusArea {
                VStack(spacing: 0) {
                    // Live Folder Status (always show when folder is selected in live mode)
                    if shouldShowLiveFolder {
                        LiveFolderUploadStatus(folderManager: folderMonitoringManager)
                    }
                    
                    // Upload Status
                    if isAnyUploadActive {
                        uploadStatusView
                    }
                    
                    // Capture One
                    if shouldShowCaptureOne {
                        CaptureOneStatusView(uploader: uploader)
                            .environmentObject(captureOneMonitor)
                            .environmentObject(captureOneUploadManager)
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 8)
            }

        }
        .padding(24)
        .animation(.easeInOut(duration: 0.3), value: shouldShowStatusArea)
    }
    
    // MARK: - Status Visibility Logic
    
    /// Determines if the entire status area should be visible
    private var shouldShowStatusArea: Bool {
        // Show if uploading OR Capture One is running (in normal mode) OR live folder is watching
        isAnyUploadActive || shouldShowCaptureOne || shouldShowLiveFolder
    }
    
    /// Determines if live folder status should be shown
    private var shouldShowLiveFolder: Bool {
        // Show when live mode is enabled AND folder is selected
        isLiveModeEnabled && folderMonitoringManager.selectedFolder != nil
    }
    
    /// Determines if Capture One status should be shown
    private var shouldShowCaptureOne: Bool {
        // Only show when:
        // - Not in live mode
        // - Capture One is actually running
        // - No uploads are active (uploads take priority)
        !isLiveModeEnabled && captureOneMonitor.isRunning && !isAnyUploadActive
    }
    
    /// Check if any upload is active from any source
    private var isAnyUploadActive: Bool {
        // Manual or Capture One upload active (both now use the same Uploader)
        let uploaderActive = (uploader.isUploading && !uploader.uploadQueue.isEmpty) || uploader.uploadState == .completed
        
        // Capture One exporting (preparing files, not yet uploading)
        let captureOneExporting = captureOneUploadManager.isExporting && !uploader.isUploading
        
        // Live folder upload active
        let liveFolderActive = folderMonitoringManager.isUploading
        
        return uploaderActive || captureOneExporting || liveFolderActive
    }
    
    /// Unified upload status view that adapts based on upload source
    @ViewBuilder
    private var uploadStatusView: some View {
        // Show Capture One exporting status (before files start uploading)
        if captureOneUploadManager.isExporting && !uploader.isUploading {
            CaptureOneExportingStatus()
        }
        // Show upload progress (used by both manual and Capture One uploads)
        else if uploader.isUploading || uploader.uploadState == .completed {
            ManualUploadStatus(uploader: uploader)
        }
    }
    
    // MARK: - File Handling
    
    private func handleFilesSelected(_ urls: [URL]) {
        print("📁 Files selected: \(urls.count)")
        uploader.queueFiles(urls)
    }
    
    // MARK: - Live Mode Handling
    
    private func handleLiveModeToggle(_ enabled: Bool) {
        if !enabled {
            // Stop watching and reset everything
            folderMonitoringManager.stopMonitoring()
        }
    }
}

// MARK: - Back Button

struct BackButton: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                Text("Galleries")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isHovered ? Color.primary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

