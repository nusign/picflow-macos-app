//
//  UploadStatusView.swift
//  Picflow
//
//  Unified upload status display for all upload types
//

import SwiftUI
import Foundation

// MARK: - Upload Status View

/// Unified reusable upload status component
/// Used by manual uploads, Capture One integration, and live folder watching
struct UploadStatusView: View {
    let state: UploadState
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon
            Image(systemName: statusIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(statusColor)
                .frame(width: 32, height: 32, alignment: .center)
            
            // Middle: Title and Status
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
    
    private var statusTitle: String {
        switch state {
        case .completed:
            return "Completed"
        default:
            return "Uploading"
        }
    }
    
    private var statusIcon: String {
        switch state {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "arrow.up.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .accentColor
        }
    }
}

// MARK: - Manual Upload Status

/// Wrapper for manual file uploads (drag & drop / choose files)
struct ManualUploadStatus: View {
    @ObservedObject var uploader: Uploader
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background capsule
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
            HStack(spacing: 12) {
                // Left side: Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 32, height: 32, alignment: .center)
                
                // Middle: Title and Status
                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text(statusDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Right side: Progress percentage
                if uploader.uploadState != .completed {
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
            return "All files uploaded successfully"
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

#if DEBUG
extension Uploader {
    @MainActor
    static func preview(
        state: UploadState,
        progress: Double = 0.55,
        queueCount: Int = 3,
        currentIndex: Int = 0,
        speed: Double = 5_500_000,
        timeRemaining: TimeInterval = 120
    ) -> Uploader {
        let uploader = Uploader()
        uploader.uploadState = state
        uploader.uploadProgress = progress
        
        if queueCount > 0 {
            let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            
            // Create temporary files with actual data for preview
            uploader.uploadQueue = (0..<queueCount).compactMap { index in
                let fileURL = tempDirectory.appendingPathComponent("preview-file-\(index + 1).jpg")
                
                // Create a small dummy file if it doesn't exist
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    // Create dummy data (10MB per file for realistic preview)
                    let dummyData = Data(count: 10_000_000)
                    try? dummyData.write(to: fileURL)
                }
                
                return fileURL
            }
            uploader.currentFileIndex = min(max(currentIndex, 0), queueCount - 1)
        } else {
            uploader.uploadQueue = []
            uploader.currentFileIndex = 0
        }
        
        uploader.uploadSpeed = speed
        uploader.estimatedTimeRemaining = timeRemaining
        return uploader
    }
}
#endif

#Preview("Upload Status States", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 16) {
        UploadStatusView(state: .uploading, description: "Uploading 2 of 5 · 48%")
        UploadStatusView(state: .completed, description: "All files uploaded successfully")
        UploadStatusView(state: .failed, description: "Network connection lost. Please retry.")
    }
    .padding()
    .frame(width: 360)
}

#Preview("Manual Upload Status States", traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 16) {
        ManualUploadStatus(
            uploader: .preview(
                state: .uploading,
                progress: 0.42,
                queueCount: 4,
                currentIndex: 1,
                speed: 6_750_000,
                timeRemaining: 95
            )
        )
        ManualUploadStatus(
            uploader: .preview(
                state: .completed,
                progress: 1.0,
                queueCount: 2,
                currentIndex: 1,
                speed: 0,
                timeRemaining: 0
            )
        )
        ManualUploadStatus(
            uploader: .preview(
                state: .failed,
                progress: 0.66,
                queueCount: 3,
                currentIndex: 2,
                speed: 3_200_000,
                timeRemaining: 180
            )
        )
    }
    .padding()
    .frame(width: 460)
}
