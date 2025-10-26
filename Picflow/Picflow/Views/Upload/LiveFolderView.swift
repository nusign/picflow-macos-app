//
//  LiveFolderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

/// View for selecting a folder to monitor for live file streaming
struct LiveFolderView: View {
    let onFolderSelected: (URL) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Icon
                Image("Folder-Sync-Connect")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                
                VStack(spacing: 8) {
                    // Title
                    Text("Picflow Live")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
    
                    // Description
                    Text("Connect a folder and stream new files to Picflow.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        }
                .frame(maxWidth: 180)
                .padding(.bottom, 16)

                // Choose Folder Button
                Button("Choose Folder") {
                    selectFolder()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 8])
                )
                .foregroundColor(Color.primary.opacity(0.2))
        )
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Streaming"
        // panel.message = "Select a folder to monitor for new files"
        
        if panel.runModal() == .OK, let url = panel.url {
            onFolderSelected(url)
        }
    }
}