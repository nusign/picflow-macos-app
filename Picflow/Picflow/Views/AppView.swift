//
//  AppView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

enum AppNavigationState {
    case workspaceSelection  // Future: when no workspace selected
    case gallerySelection    // When workspace selected but no gallery
    case uploader            // When gallery selected
}

struct AppView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    @State private var navigationState: AppNavigationState = .gallerySelection
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main Navigation Content with Transitions
            ZStack {
                if navigationState == .gallerySelection {
                    GallerySelectionView(
                        uploader: uploader,
                        onGallerySelected: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navigationState = .uploader
                            }
                        }
                    )
                    .environmentObject(authenticator)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                if navigationState == .uploader {
                    UploaderView(
                        uploader: uploader,
                        authenticator: authenticator,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                navigationState = .gallerySelection
                            }
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                }
                
                // Future: Workspace Selection
                // if navigationState == .workspaceSelection { ... }
            }
            .padding()
            .padding(.top, 8) // Extra padding for traffic lights
            .frame(minWidth: 480, minHeight: 700)
            .background(Color.clear) // Transparent to show visual effect view
            
            // Avatar Overlay - Always visible when authenticated
            if case .authorized(_, let profile) = authenticator.state {
                UserProfileView(profile: profile, authenticator: authenticator)
                    .padding(.top, 8)
                    .padding(.trailing, 16)
            }
        }
        .onChange(of: uploader.selectedGallery) { _, newValue in
            // Sync navigation state with uploader state
            if newValue != nil && navigationState != .uploader {
                withAnimation(.easeInOut(duration: 0.3)) {
                    navigationState = .uploader
                }
            } else if newValue == nil && navigationState == .uploader {
                withAnimation(.easeInOut(duration: 0.3)) {
                    navigationState = .gallerySelection
                }
            }
        }
    }
}

