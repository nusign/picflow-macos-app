//
//  UploadStatusView.swift
//  Picflow
//
//  Unified upload status display for all upload types
//

import SwiftUI

// MARK: - Upload Status View

/// Unified reusable upload status component
/// Used by manual uploads, Capture One integration, and live folder watching
struct UploadStatusView: View {
    let state: UploadState
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            // Middle: Title and Status
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
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
        let totalFiles = uploader.uploadQueue.count
        let currentIndex = uploader.currentFileIndex + 1
        
        // Format speed in Mbps
        let speedMbps = (uploader.uploadSpeed * 8) / 1_000_000
        let speedText = String(format: "%.1f Mbit/s", speedMbps)
        
        // Format remaining time
        let timeRemaining = Int(uploader.estimatedTimeRemaining)
        let timeText = timeRemaining > 0 ? "\(timeRemaining)s remaining" : ""
        
        // Build description
        let description: String
        if uploader.uploadState == .completed {
            description = "All files uploaded successfully"
        } else if totalFiles > 1 {
            var parts: [String] = []
            parts.append("\(currentIndex) of \(totalFiles)")
            if !timeText.isEmpty {
                parts.append(timeText)
            }
            if speedMbps > 0 {
                parts.append(speedText)
            }
            description = parts.joined(separator: ", ")
        } else {
            description = speedMbps > 0 ? speedText : "Uploading..."
        }
        
        return UploadStatusView(
            state: uploader.uploadState,
            description: description
        )
    }
}


