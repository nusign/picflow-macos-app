//
//  UploadStatusView.swift
//  Picflow
//
//  Upload status components for different upload sources:
//  1. ManualUploadStatus - Full-featured upload progress (manual & Capture One)
//  2. LiveFolderUploadStatus - Live mode with progress bar & pulsing animation
//
//  Note: CaptureOneExportingStatus is in CaptureOneStatusView.swift
//

import SwiftUI
import Foundation

// MARK: - Manual Upload Status (Drag & Drop / File Picker / Capture One)

/// Full-featured upload status with progress tracking
/// Used for: Manual uploads (drag & drop, file picker) AND Capture One uploads
/// Features: Animated progress bar, speed, time remaining, file counter, Cancel button
struct ManualUploadStatus: View {
    @ObservedObject var uploader: Uploader
    
    var body: some View {
        ZStack(alignment: .leading) {
            // BACKGROUND: Animated progress bar (fills left-to-right as upload progresses)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if uploader.uploadState == .completed {
                        // Green background when completed
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    } else {
                        // Progress bar background during upload
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                        
                        // Animated progress indicator
                        if uploader.uploadState == .uploading {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.1))
                                .frame(width: max(geometry.size.width * uploader.uploadProgress, geometry.size.height))
                                .animation(.linear(duration: 0.3), value: uploader.uploadProgress)
                        }
                    }
                }
            }
            
            // Content (on top of progress bar)
            HStack(spacing: 8) {
                // Left side: Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 32, height: 32, alignment: .center)
                
                // Middle: Title and Status
                VStack(alignment: .leading, spacing: 0) {
                    Text(statusTitle)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(statusDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right side: Cancel button or Progress percentage
                if uploader.uploadState == .uploading && !uploader.isCancelling {
                    Button {
                        uploader.cancelAllUploads()
                    } label: {
                        Text("Cancel")
                            .frame(minWidth: 60)
                    }
                    .applySecondaryButtonStyle()
                    .controlSize(.large)
                    .padding(.trailing, 8)

                } else if uploader.uploadState == .uploading {
                    // Show progress percentage while uploading
                    Text("\(Int(uploader.uploadProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(12)
        }
        .frame(height: 60)
    }
    
    private var totalFiles: Int {
        uploader.uploadQueue.count
    }
    
    private var currentIndex: Int {
        uploader.currentFileIndex + 1
    }
    
    private var statusTitle: String {
        switch uploader.uploadState {
        case .completed:
            return "Completed"
        default:
            // Show file count in title for multiple files
            if totalFiles > 1 {
                return "Uploading \(currentIndex) of \(totalFiles)"
            } else {
                return "Uploading"
            }
        }
    }
    
    private var statusIcon: String {
        switch uploader.uploadState {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "arrow.up.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch uploader.uploadState {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .accentColor
        }
    }
    
    private var statusDescription: String {
        if uploader.uploadState == .completed {
            return "Uploaded successfully"
        }
        
        var parts: [String] = []
        
        // Total file size
        let totalSizeMB = Double(totalFileSize) / 1_000_000
        parts.append(String(format: "%.1f MB", totalSizeMB))
        
        // Time remaining (always show MM:SS format)
        let timeRemaining = uploader.estimatedTimeRemaining
        if timeRemaining > 0 {
            parts.append("\(formatTimeRemaining(timeRemaining)) remaining")
        }
        
        // Speed in parentheses
        let speedMbps = (uploader.uploadSpeed * 8) / 1_000_000
        if speedMbps > 0 {
            parts.append("(\(String(format: "%.1f Mbit/s", speedMbps)))")
        }
        
        return parts.joined(separator: " · ")
    }
    
    /// Calculate total size of all files in upload queue
    private var totalFileSize: Int64 {
        var total: Int64 = 0
        for fileURL in uploader.uploadQueue {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let fileSize = attributes[.size] as? Int64 {
                total += fileSize
            }
        }
        return total
    }
    
    /// Format time remaining as MM:SS or H:MM:SS
    private func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}

// MARK: - Live Folder Upload Status (Live Mode)

/// Full-featured upload status for live folder monitoring
/// Features: Animated progress bar background, pulsing red dot, upload counter
struct LiveFolderUploadStatus: View {
    @ObservedObject var folderManager: FolderMonitoringManager
    @State private var isPulsing = false
    
    var body: some View {
        ZStack(alignment: .leading) {
            // BACKGROUND: Animated progress bar (fills left-to-right as upload progresses)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    if folderManager.uploadState == .completed {
                        // Green background when completed
                        Capsule()
                            .fill(Color.green.opacity(0.1))
                    } else if folderManager.uploadState == .failed {
                        // Red background when failed
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    } else if folderManager.uploadState == .idle {
                        // Light red background for live streaming active
                        Capsule()
                            .fill(Color.red.opacity(0.1))
                    } else {
                        // Base background for uploading
                        Capsule()
                            .fill(Color.accentColor.opacity(0.1))
                        
                        // Animated progress indicator (only when uploading)
                        if folderManager.uploadState == .uploading {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.2))
                                .frame(width: max(geometry.size.width * folderManager.uploadProgress, geometry.size.height))
                                .animation(.linear(duration: 0.3), value: folderManager.uploadProgress)
                        }
                    }
                }
            }
            
            // Content (on top of background)
            HStack(spacing: 8) {
                // Left side: Icon with pulsing animation for live mode
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 32, height: 32, alignment: .center)
                    .opacity(isLiveModeActive ? (isPulsing ? 0.4 : 1.0) : 1.0)
                    .animation(
                        isLiveModeActive ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                        value: isPulsing
                    )
                    .onAppear {
                        if isLiveModeActive {
                            isPulsing = true
                        }
                    }
                    .onChange(of: folderManager.uploadState) { _, _ in
                        isPulsing = isLiveModeActive
                    }
                
                // Middle: Title and Status
                VStack(alignment: .leading, spacing: 0) {
                    Text(statusTitle)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(folderManager.statusDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right side: Cancel button or progress percentage
                if folderManager.uploadState == .uploading && folderManager.uploadProgress > 0 {
                    // Show progress percentage while uploading
                    Text("\(Int(folderManager.uploadProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                } else {
                    // Cancel button - same style as ManualUploadStatus
                    Button {
                        folderManager.stopMonitoring()
                    } label: {
                        Text("Cancel")
                            .frame(minWidth: 60)
                    }
                    .applySecondaryButtonStyle()
                    .controlSize(.large)
                    .padding(.trailing, 8)
                }
            }
            .padding(12)
        }
        .frame(height: 60)
    }
    
    private var isLiveModeActive: Bool {
        folderManager.uploadState == .idle
    }
    
    private var statusTitle: String {
        switch folderManager.uploadState {
        case .idle:
            return "Streaming Folder"
        case .uploading:
            return "Uploading"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }
    
    private var statusIcon: String {
        switch folderManager.uploadState {
        case .idle:
            return "circle.fill"
        case .uploading:
            return "arrow.up.circle.fill"
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        switch folderManager.uploadState {
        case .idle:
            return .red  // Red for active live streaming
        case .uploading:
            return .accentColor
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}
