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
            
            // Title and Status
            VStack(alignment: .leading, spacing: 4) {
                Text("Capture One")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(monitor.isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(monitor.isRunning ? "Running" : "Not Running")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Right side: Permission or Upload button
            if monitor.isRunning {
                if monitor.needsPermission {
                    Button("Allow Access") {
                        monitor.requestPermission()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else if monitor.selection.count > 0 {
                    Button {
                        // TODO: Implement export and upload
                        print("Upload \(monitor.selection.count) selected files")
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle.fill")
                            Text("Upload")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                } else {
                    // Placeholder disabled upload button
                    Button {
                        // No action
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.circle")
                            Text("Upload")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
