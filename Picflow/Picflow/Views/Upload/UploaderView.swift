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
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                // Gallery Title (centered)
                HStack {
                    Spacer()
                    Text(uploader.selectedGallery?.displayName ?? "Gallery")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                    Spacer()
                }
                
                // Back Button and Live Toggle
                HStack {
                    BackButton(action: onBack)
                    
                    Spacer()
                    
                    // Live Mode Toggle
                    Toggle("Live", isOn: $isLiveModeEnabled)
                        .toggleStyle(.switch)
                }
            }
            .padding()
            
            // Main Content Area (fills available vertical space)
            if isLiveModeEnabled {
                LiveFolderView(onFolderSelected: handleFolderSelected)
                    .frame(maxHeight: .infinity)
            } else {
                DropAreaView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                    .frame(maxHeight: .infinity)
            }
            
            // Bottom components - Unified visibility logic
            VStack(spacing: 16) {
                // Show upload status when ANY upload is active
                if isAnyUploadActive {
                    uploadStatusView
                }
                
                // Show Capture One only when:
                // - NOT in Live mode
                // - AND no uploads happening from any source
                if !isLiveModeEnabled && !isAnyUploadActive {
                    CaptureOneStatusView(uploader: uploader)
                        .environmentObject(captureOneMonitor)
                        .environmentObject(captureOneUploadManager)
                }
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - Upload Status Logic
    
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

