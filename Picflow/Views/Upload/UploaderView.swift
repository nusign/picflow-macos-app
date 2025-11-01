//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI
import AppKit

enum UploaderTab: String, CaseIterable {
    case upload = "Upload"
    case stream = "Stream"
}

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onBack: () -> Void
    @State private var isDragging = false
    @State private var selectedTab: UploaderTab = .upload
    @State private var showGalleryMenu = false
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    
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
            // Main Content Area (fills available vertical space)
            Group {
                switch selectedTab {
                case .upload:
                    DropAreaView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                        .frame(maxHeight: .infinity)
                case .stream:
                    LiveFolderView(folderManager: folderMonitoringManager)
                        .frame(maxHeight: .infinity)
                }
            }
            .padding(.bottom, 12)
            
            // Status Components (Upload progress and Capture One Integration)
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
                .padding(0)
            }

        }
        .padding(.top, 0)
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.3), value: shouldShowStatusArea)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .help("Back to Gallery Selection")
            }

            ToolbarItem(placement: .principal) {
                Spacer()
            }

            ToolbarItem(placement: .automatic) {
                Picker("", selection: $selectedTab) {
                    ForEach(UploaderTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTab) { _, newValue in
                    handleTabChange(newValue)
                }
            }

            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showGalleryMenu.toggle()
                }) {
                    Image(systemName: "ellipsis")
                }
                .help("More Options")
                .popover(isPresented: $showGalleryMenu, arrowEdge: .bottom) {
                    GalleryMenuContent(
                        uploader: uploader,
                        authenticator: authenticator,
                        onCopyLink: copyGalleryLink,
                        onOpenInPicflow: openGalleryInPicflow,
                        onDeleteGallery: deleteGallery
                    )
                }
            }

        }
        .alert("Delete Gallery", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await confirmDeleteGallery()
                }
            }
        } message: {
            if isDeleting {
                Text("Deleting gallery...")
            } else {
                Text("Are you sure you want to delete \"\(uploader.selectedGallery?.displayName ?? "this gallery")\"? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - Status Visibility Logic
    
    /// Determines if the entire status area should be visible
    private var shouldShowStatusArea: Bool {
        // Show if uploading OR Capture One is running (in normal mode) OR live folder is watching
        isAnyUploadActive || shouldShowCaptureOne || shouldShowLiveFolder
    }
    
    /// Determines if live folder status should be shown
    private var shouldShowLiveFolder: Bool {
        // Show when stream tab is active AND folder is selected
        selectedTab == .stream && folderMonitoringManager.selectedFolder != nil
    }
    
    /// Determines if Capture One status should be shown
    private var shouldShowCaptureOne: Bool {
        // Only show when:
        // - In upload tab (not stream)
        // - Capture One is actually running
        // - No uploads are active (uploads take priority)
        selectedTab == .upload && captureOneMonitor.isRunning && !isAnyUploadActive
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
    
    // MARK: - Tab Handling
    
    private func handleTabChange(_ newTab: UploaderTab) {
        if newTab == .upload {
            // Stop watching and reset when switching away from stream tab
            folderMonitoringManager.stopMonitoring()
        }
    }
    
    // MARK: - Gallery Menu Actions
    
    private func copyGalleryLink() {
        guard let gallery = uploader.selectedGallery,
              let tenant = authenticator.tenant else { return }
        
        // Shareable link format: tenant-slug.picflow.com/gallery-path
        let tenantSlug = tenant.path.replacingOccurrences(of: "/t/", with: "")
        let domain = EnvironmentManager.shared.current == .development ? "dev.picflow.com" : "picflow.com"
        // Ensure gallery path starts with / if not already present
        let galleryPath = gallery.path.hasPrefix("/") ? gallery.path : "/\(gallery.path)"
        let galleryUrl = "https://\(tenantSlug).\(domain)\(galleryPath)"
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(galleryUrl, forType: .string)
        
        showGalleryMenu = false
    }
    
    private func openGalleryInPicflow() {
        guard let gallery = uploader.selectedGallery else { return }
        
        // Internal app link format: picflow.com/a/gallery/{galleryId}/
        let domain = EnvironmentManager.shared.current == .development ? "dev.picflow.com" : "picflow.com"
        let galleryUrl = "https://\(domain)/a/gallery/\(gallery.id)/"
        if let url = URL(string: galleryUrl) {
            NSWorkspace.shared.open(url)
        }
        
        showGalleryMenu = false
    }
    
    private func deleteGallery() {
        showGalleryMenu = false
        showDeleteAlert = true
    }
    
    private func confirmDeleteGallery() async {
        guard let gallery = uploader.selectedGallery else { return }
        
        isDeleting = true
        
        do {
            let deleteRequest = DeleteGalleryRequest(galleryId: gallery.id)
            try await deleteRequest.endpoint().performRequest()
            
            // Success - navigate back to gallery selection
            await MainActor.run {
                isDeleting = false
                uploader.selectedGallery = nil
                onBack()
            }
        } catch {
            // Handle error
            await MainActor.run {
                isDeleting = false
                // Show error alert
                ErrorAlertManager.shared.showError(
                    title: "Delete Failed",
                    message: "Could not delete gallery: \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Gallery Menu

struct GalleryMenuContent: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onCopyLink: () -> Void
    let onOpenInPicflow: () -> Void
    let onDeleteGallery: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            GalleryMenuItem(icon: "link", title: "Copy Link") {
                onCopyLink()
            }
            
            GalleryMenuItem(icon: "arrow.up.forward.app", title: "Open in Picflow") {
                onOpenInPicflow()
            }
            
            Divider()
                .padding(.vertical, 4)
            
            GalleryMenuItem(icon: "trash", title: "Delete Gallery", isDestructive: true) {
                onDeleteGallery()
            }
        }
        .padding(.vertical, 4)
        .frame(width: 200)
        .focusable(false)
    }
}

struct GalleryMenuItem: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

