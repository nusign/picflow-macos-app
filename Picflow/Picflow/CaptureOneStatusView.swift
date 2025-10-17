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
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Capture One Integration")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Running status
            HStack(spacing: 12) {
                Circle()
                    .fill(monitor.isRunning ? Color.green : Color.red)
                    .frame(width: 20, height: 20)
                    .shadow(color: monitor.isRunning ? .green.opacity(0.5) : .red.opacity(0.5), radius: 4)
                
                Text(monitor.isRunning ? "Running" : "Not Running")
                    .font(.headline)
                    .foregroundColor(monitor.isRunning ? .green : .red)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.1))
            )
            
            // Selection info
            if monitor.isRunning {
                VStack(spacing: 12) {
                    if monitor.needsPermission {
                        // Permission request UI
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.shield")
                                    .foregroundColor(.orange)
                                Text("Permission Required")
                                    .font(.headline)
                            }
                            
                            Text("Picflow needs permission to read your Capture One selection")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                monitor.requestPermission()
                            } label: {
                                HStack {
                                    Image(systemName: "key.fill")
                                    Text("Grant Permission")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.1))
                        )
                    } else if monitor.isLoadingSelection {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Reading selection...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    } else if let error = monitor.selectionError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    } else {
                        // Selection count
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .foregroundColor(.accentColor)
                            Text("\(monitor.selection.count) asset\(monitor.selection.count == 1 ? "" : "s") selected")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        
                        // Show single asset details
                        if let variant = monitor.selection.singleVariant {
                            assetDetailsView(variant: variant)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            
            // Manual refresh button
            Button {
                monitor.refresh()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
            }
            .buttonStyle(.bordered)
            .disabled(monitor.isLoadingSelection)
        }
        .padding()
        .frame(minWidth: 400)
    }
    
    @ViewBuilder
    private func assetDetailsView(variant: CaptureOneVariant) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("Selected Asset")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 6) {
                // Name
                HStack {
                    Image(systemName: "doc")
                    Text(variant.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                // File path
                if let filePath = variant.filePath {
                    HStack(alignment: .top) {
                        Image(systemName: "folder")
                        Text(filePath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Rating and color tag
                HStack(spacing: 16) {
                    if let rating = variant.rating {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("\(rating)")
                                .font(.caption)
                        }
                    }
                    
                    if let colorTag = variant.colorTag {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForTag(colorTag))
                                .frame(width: 12, height: 12)
                            Text("Tag \(colorTag)")
                                .font(.caption)
                        }
                    }
                }
                
                // Camera info
                if let make = variant.cameraMake, let model = variant.cameraModel {
                    HStack {
                        Image(systemName: "camera")
                        Text("\(make) \(model)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Shooting info
                HStack(spacing: 12) {
                    if let iso = variant.iso {
                        HStack(spacing: 2) {
                            Text("ISO")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(iso)
                                .font(.caption)
                        }
                    }
                    
                    if let aperture = variant.aperture {
                        Text(aperture)
                            .font(.caption)
                    }
                    
                    if let shutter = variant.shutterSpeed {
                        Text(shutter)
                            .font(.caption)
                    }
                    
                    if let focal = variant.focalLength {
                        Text(focal)
                            .font(.caption)
                    }
                }
                
                // Crop dimensions
                if let width = variant.cropWidth, let height = variant.cropHeight {
                    HStack {
                        Image(systemName: "crop")
                        Text("\(width) × \(height) px")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .padding(.horizontal)
        }
    }
    
    private func colorForTag(_ tag: Int) -> Color {
        switch tag {
        case 0: return .red
        case 1: return .orange
        case 2: return .yellow
        case 3: return .green
        case 4: return .blue
        case 5: return .purple
        case 6: return .pink
        default: return .gray
        }
    }
}

// Preview for development
#Preview {
    CaptureOneStatusView()
}

