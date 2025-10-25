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
            
            VStack(spacing: 20) {
                // Folder Sync Icon
                Image("Folder-Sync-Connect")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                
                // Title
                Text("Picflow Live")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Description
                Text("Connect a folder and stream new files to Picflow.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
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
        panel.prompt = "Choose Folder"
        panel.message = "Select a folder to monitor for new files"
        
        if panel.runModal() == .OK, let url = panel.url {
            onFolderSelected(url)
        }
    }
}

