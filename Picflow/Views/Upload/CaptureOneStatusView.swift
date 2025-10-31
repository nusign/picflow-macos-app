//
//  CaptureOneStatusView.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import SwiftUI

/// Displays the current status of Capture One with a colored indicator
struct CaptureOneStatusView: View {
    @EnvironmentObject var monitor: CaptureOneMonitor
    @EnvironmentObject var uploadManager: CaptureOneUploadManager
    @ObservedObject var uploader: Uploader
    
    @State private var showRunningStatus = true
    @State private var statusSwitchTask: Task<Void, Never>?
    
    var body: some View {
        // Only show integration status when idle (upload status is handled by UploaderView)
        if monitor.isRunning {
            statusContent
                .onAppear {
                    // Show "Running" for 2 seconds when view appears
                    showRunningStatusTemporarily()
                    // Immediately fetch selection count (don't wait for poll)
                    Task {
                        await monitor.refresh()
                    }
                }
                .onChange(of: monitor.isRunning) { _, isRunning in
                    if isRunning {
                        // Show "Running" for 2 seconds when C1 starts
                        showRunningStatusTemporarily()
                        // Immediately fetch selection count (don't wait for poll)
                        Task {
                            await monitor.refresh()
                        }
                    }
                }
        }
    }
    
    private func showRunningStatusTemporarily() {
        statusSwitchTask?.cancel()
        
        showRunningStatus = true
        
        statusSwitchTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            guard !Task.isCancelled else { return }
            
            showRunningStatus = false
        }
    }
    
    @ViewBuilder
    private var statusContent: some View {
        HStack(spacing: 8) {
            // App Icon
            Image("Capture-One-Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title and Status (crossfades between "Running" and selection count)
            VStack(alignment: .leading, spacing: 0) {
                Text(monitor.selection.documentName ?? "Capture One")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(monitor.needsPermission ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    
                    Group {
                        if monitor.needsPermission {
                            // Show permission status
                            Text("Privacy & Security → Automation")
                        } else if showRunningStatus || monitor.selection.documentName == nil {
                            // Show "Running" if timer is active OR if we don't have document name yet
                            Text("Running")
                        } else {
                            if monitor.selection.count > 0 {
                                Text("\(monitor.selection.count) variant\(monitor.selection.count == 1 ? "" : "s") selected")
                            } else {
                                Text("No variants selected")
                            }
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .animation(.easeInOut(duration: 0.3), value: showRunningStatus)
                }
            }
            
            Spacer()
            
            // Right side: Upload button (no animation)
            if monitor.needsPermission {
                if monitor.hasAttemptedPermission {
                    // User has tried before and denied - need to use System Settings
                    Button("Open System Settings") {
                        monitor.openAutomationSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    // First time - show permission prompt
                    Button("Allow Access") {
                        monitor.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else if monitor.selection.count > 0 {
                Menu {
                    Button("Picflow Recipe") {
                        Task {
                            await handleExportAndUpload()
                        }
                    }
                    
                    Button("Original Files") {
                        Task {
                            await handleUploadOriginals()
                        }
                    }
                } label: {
                    Text(uploadManager.isExporting ? "Exporting..." : "Upload")
                } primaryAction: {
                    Task {
                        await handleExportAndUpload()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(uploadManager.isExporting)
            }
        }
        .padding(12)
        .frame(height: 60)
    }
    
    // MARK: - Upload Actions
    
    /// Handle export and upload workflow
    private func handleExportAndUpload() async {
        // Refresh selection count immediately before export
        await monitor.refresh()
        
        // Verify still have selection after refresh
        if monitor.selection.count > 0 {
            print("📸 Exporting \(monitor.selection.count) selected variants")
            await uploadManager.exportAndUpload(uploader: uploader)
        } else {
            uploadManager.error = "No variants selected. Please select variants in Capture One."
        }
    }
    
    /// Handle upload original files workflow
    private func handleUploadOriginals() async {
        // Refresh selection count immediately before upload
        await monitor.refresh()
        
        // Verify still have selection after refresh
        if monitor.selection.count > 0 {
            print("📸 Uploading \(monitor.selection.count) original files")
            await uploadManager.uploadOriginalFiles(uploader: uploader)
        } else {
            uploadManager.error = "No variants selected. Please select variants in Capture One."
        }
    }
}

// MARK: - Capture One Export Status

/// Status display shown during Capture One export preparation phase
/// Shows "Waiting for export..." with Capture One branding
/// Once files start uploading, the main upload view switches to ManualUploadStatus
struct CaptureOneExportingStatus: View {
    var body: some View {
        HStack(spacing: 8) {
            // Left side: Capture One Logo
            Image("Capture-One-Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Middle: Title and Status
            VStack(alignment: .leading, spacing: 0) {
                Text("Capture One")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text("Waiting for export...")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .frame(height: 60)
    }
}