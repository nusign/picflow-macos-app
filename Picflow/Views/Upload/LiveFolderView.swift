//
//  LiveFolderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

/// View for selecting a folder to monitor for live file streaming
struct LiveFolderView: View {
    @ObservedObject var folderManager: FolderMonitoringManager
    
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

                // Choose/Change Folder Button
                Button {
                    selectFolder()
                } label: {
                    Label(buttonTitle, systemImage: buttonIcon)
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
    
    private var buttonTitle: String {
        if let folderName = folderManager.folderName {
            return folderName
        } else {
            return "Choose Folder"
        }
    }
    
    private var buttonIcon: String {
        if folderManager.folderName != nil {
            return "arrow.up.folder.fill"
        } else {
            return "folder"
        }
    }
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Start Streaming"
        
        if panel.runModal() == .OK, let url = panel.url {
            folderManager.selectFolder(url)
        }
    }
}