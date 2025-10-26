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
                }
                .onChange(of: monitor.isRunning) { _, isRunning in
                    if isRunning {
                        // Show "Running" for 2 seconds when C1 starts
                        showRunningStatusTemporarily()
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
        HStack(spacing: 12) {
            // App Icon
            Image("Capture-One-Logo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Title and Status (crossfades between "Running" and selection count)
            VStack(alignment: .leading, spacing: 0) {
                Text("Capture One")
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    if showRunningStatus {
                        Text("Running")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        if monitor.selection.count > 0 {
                            Text("\(monitor.selection.count) variant\(monitor.selection.count == 1 ? "" : "s") selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No variants selected")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showRunningStatus)
            }
            
            Spacer()
            
            // Right side: Upload button (independent of text transition)
            if monitor.needsPermission {
                Button("Allow Access") {
                    monitor.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if monitor.selection.count > 0 {
                // Upload button with menu (appears when variants selected, independent of "Running" text)
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
        
        // Show recipe path error prompt (separate from main status)
        if uploadManager.showRecipePathError {
            recipePathErrorPrompt
        }
    }
    
    @ViewBuilder
    private var recipePathErrorPrompt: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Export location in Recipe might be wrong")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text("The exported files didn't appear in the expected folder")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Recreate Recipe") {
                Task {
                    await uploadManager.recreateRecipe()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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