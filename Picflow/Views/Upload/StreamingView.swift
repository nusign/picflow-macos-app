//
//  StreamingView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

/// View for selecting a folder to monitor for live file streaming
struct StreamingView: View {
    @ObservedObject var folderManager: FolderMonitoringManager
    
    var body: some View {
        Group {
            if folderManager.selectedFolder != nil {
                // Status view when folder is connected
                streamingStatusView
            } else {
                // Folder selection UI
                folderSelectionView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Folder Selection View
    
    private var folderSelectionView: some View {
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
                    Text("Stream")
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
                Button {
                    selectFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder")
                }
                .applySecondaryButtonStyle()
                .controlSize(.large)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Streaming Status View
    
    private var streamingStatusView: some View {
        VStack {
            Spacer()
            
            StreamCounterView(
                count: folderManager.totalUploaded,
                folderName: folderManager.folderName,
                onFolderSelect: selectFolder
            )
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = folderManager.selectedFolder != nil ? "Change Folder" : "Start Streaming"
        
        if panel.runModal() == .OK, let url = panel.url {
            folderManager.selectFolder(url)
        }
    }
}
