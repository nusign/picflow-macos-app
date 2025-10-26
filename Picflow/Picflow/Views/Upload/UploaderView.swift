//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//
//  Debug borders: Uses feature-specific borders (D)
//

import SwiftUI

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    @Environment(\.showDebugBorders) var showDebugBorders
    let onBack: () -> Void
    @State private var isDragging = false
    @State private var isLiveModeEnabled = false
    
    // Access Capture One upload manager for unified visibility logic
    @StateObject private var captureOneMonitor = CaptureOneMonitor()
    @StateObject private var captureOneUploadManager = CaptureOneUploadManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Gallery Title (centered, minimal)
            HStack {
                Spacer()
                Text(uploader.selectedGallery?.displayName ?? "Gallery")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                    .border(showDebugBorders ? Color.orange : Color.clear, width: 1) // DEBUG: Title
                Spacer()
            }
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
                }
                .border(showDebugBorders ? Color.green : Color.clear, width: 1) // DEBUG: Controls HStack
                
                // Main Content Area (fills available vertical space)
                if isLiveModeEnabled {
                    LiveFolderView(onFolderSelected: handleFolderSelected)
                        .frame(maxHeight: .infinity)
                        .border(showDebugBorders ? Color.purple : Color.clear, width: 2) // DEBUG: LiveFolderView
                } else {
                    DropAreaView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                        .frame(maxHeight: .infinity)
                        .border(showDebugBorders ? Color.cyan : Color.clear, width: 2) // DEBUG: DropAreaView
                }
            }
            .border(showDebugBorders ? Color.yellow : Color.clear, width: 2) // DEBUG: Content VStack
            
            // Status Components (Upload progress or Capture One Integration)
            if shouldShowStatusArea {
                VStack(spacing: 0) {
                    // Upload Status
                    if isAnyUploadActive {
                        uploadStatusView
                            .border(showDebugBorders ? Color.pink : Color.clear, width: 1) // DEBUG: Upload Status
                    }
                    
                    // Capture One
                    if shouldShowCaptureOne {
                        CaptureOneStatusView(uploader: uploader)
                            .environmentObject(captureOneMonitor)
                            .environmentObject(captureOneUploadManager)
                            .border(showDebugBorders ? Color.mint : Color.clear, width: 1) // DEBUG: Capture One
                    }
                }
                .padding(.top, 16)
                .padding(.horizontal, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

        }
        .padding(24)
        .border(showDebugBorders ? Color.red : Color.clear, width: 3) // DEBUG: Outer VStack
        .animation(.easeInOut(duration: 0.3), value: shouldShowStatusArea)
    }
    
    // MARK: - Status Visibility Logic
    
    /// Determines if the entire status area should be visible
    private var shouldShowStatusArea: Bool {
        // Show if uploading OR Capture One is running (in normal mode)
        isAnyUploadActive || shouldShowCaptureOne
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
        // Manual upload active
        let manualActive = (uploader.isUploading && !uploader.uploadQueue.isEmpty) || uploader.uploadState == .completed
        
        // Capture One upload active
        let captureOneActive = captureOneUploadManager.isExporting || 
                               captureOneUploadManager.uploadState == .uploading ||
                               captureOneUploadManager.uploadState == .completed
        
        // TODO: Add live folder monitoring check when implemented
        // let liveFolderActive = liveFolderManager.isUploading
        
        return manualActive || captureOneActive
    }
    
    /// Unified upload status view that adapts based on upload source
    @ViewBuilder
    private var uploadStatusView: some View {
        // Prioritize Capture One if it's uploading
        if captureOneUploadManager.isExporting || captureOneUploadManager.uploadState == .uploading {
            UploadStatusView(
                state: captureOneUploadManager.uploadState,
                description: captureOneUploadManager.statusDescription
            )
        }
        // Then show manual upload
        else if uploader.isUploading || uploader.uploadState == .completed {
            ManualUploadStatus(uploader: uploader)
        }
        // TODO: Add live folder upload status when implemented
    }
    
    // MARK: - File Handling
    
    private func handleFilesSelected(_ urls: [URL]) {
        print("📁 Files selected: \(urls.count)")
        uploader.queueFiles(urls)
    }
    
    // MARK: - Folder Handling
    
    private func handleFolderSelected(_ url: URL) {
        print("📂 Folder selected for live monitoring: \(url.path)")
        // TODO: Implement folder monitoring logic
        // This will start watching the folder and upload new files automatically
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

