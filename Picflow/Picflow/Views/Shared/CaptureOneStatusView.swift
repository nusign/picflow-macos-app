//
//  CaptureOneStatusView.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import SwiftUI

/// Displays the current status of Capture One with a colored indicator
struct CaptureOneStatusView: View {
    @StateObject private var monitor = CaptureOneMonitor()
    @StateObject private var uploadManager = CaptureOneUploadManager()
    @ObservedObject var uploader: Uploader
    
    @State private var showRunningStatus = true
    @State private var statusSwitchTask: Task<Void, Never>?
    
    var body: some View {
        VStack(spacing: 12) {
            // Upload Progress (when exporting/uploading)
            if uploadManager.isExporting {
                GenericUploadProgressView(
                    state: uploadManager.uploadState,
                    description: uploadManager.statusDescription
                )
            }
            
            // Integration Status (when not uploading)
            if monitor.isRunning && !uploadManager.isExporting {
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
    }
    
    private func showRunningStatusTemporarily() {
        statusSwitchTask?.cancel()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showRunningStatus = true
        }
        
        statusSwitchTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.easeInOut(duration: 0.3)) {
                showRunningStatus = false
            }
        }
    }
    
    @ViewBuilder
    private var statusContent: some View {
        HStack(spacing: 12) {
            // App Icon (32px placeholder)
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text("C1")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                )
            
            // Title and Status (crossfades between "Running" and selection count)
            VStack(alignment: .leading, spacing: 4) {
                Text("Capture One")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    
                    if showRunningStatus {
                        Text("Running")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    } else {
                        if monitor.selection.count > 0 {
                            Text("\(monitor.selection.count) variant\(monitor.selection.count == 1 ? "" : "s") selected")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        } else {
                            Text("No variants selected")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .transition(.opacity)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Right side: Upload button
            if monitor.needsPermission {
                Button("Allow Access") {
                    monitor.requestPermission()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                // Upload button with menu (only when variants are selected)
                if monitor.selection.count > 0 {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
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

