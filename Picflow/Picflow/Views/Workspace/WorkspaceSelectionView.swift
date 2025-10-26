//
//  WorkspaceSelectionView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct WorkspaceSelectionView: View {
    @ObservedObject var authenticator: Authenticator
    let onWorkspaceSelected: () -> Void
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                // Top bar with avatar button
                HStack {
                    Spacer()
                    AvatarToolbarButton(authenticator: authenticator)
                        .padding(.trailing, 8)
                }
                
                // Title
                HStack {
                    Spacer()
                    Text("Choose Workspace")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
            }
            .padding()
            
            // Placeholder Content
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "building.2")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Workspace Selection")
                    .font(.headline)
                
                Text("This view will show available workspaces")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Temporary: Skip to gallery selection
                Button("Continue (Skip for now)") {
                    onWorkspaceSelected()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
            
            Spacer()
            
            // TODO: Replace with actual workspace list
            // ScrollView {
            //     LazyVStack(alignment: .leading, spacing: 10) {
            //         ForEach(workspaces, id: \.id) { workspace in
            //             Button {
            //                 selectWorkspace(workspace)
            //                 onWorkspaceSelected()
            //             } label: {
            //                 WorkspaceCardView(workspace: workspace)
            //             }
            //         }
            //     }
            //     .padding()
            // }
        }
    }
}

