//
//  AppView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

//

enum AppNavigationState {
    case workspaceSelection  // Workspace selection when no workspace is selected or switching
    case gallerySelection    // When workspace selected but no gallery
    case gallery             // When gallery selected
}

struct AppView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    @State private var navigationState: AppNavigationState = .workspaceSelection
    @State private var forceShowWorkspaceSelection: Bool = false // True when user explicitly clicks "Switch Workspace"
    
    private var navigationTitle: String {
        switch navigationState {
        case .workspaceSelection:
            return "Picflow"
        case .gallerySelection:
            return "Picflow"
        case .gallery:
            return uploader.selectedGallery?.displayName ?? "Gallery"
        }
    }
    
    private var navigationSubtitle: String {
        switch navigationState {
        case .workspaceSelection:
            return "Workspaces"
        case .gallerySelection:
            return authenticator.tenant?.name ?? "Workspace"
        case .gallery:
            return authenticator.tenant?.name ?? "Workspace"
        }
    }
    
    var body: some View {
        // Main Navigation Content
        // Avatar is overlaid at top-right, stays fixed during navigation
        ZStack {
            if navigationState == .workspaceSelection {
                WorkspaceSelectionView(
                    authenticator: authenticator,
                    onTenantSelected: {
                        navigationState = .gallerySelection
                        forceShowWorkspaceSelection = false // Reset after selection
                    },
                    forceShowSelection: forceShowWorkspaceSelection
                )
                .transition(.identity) // No transition animation
            }
            
            if navigationState == .gallerySelection {
                GallerySelectionView(
                    uploader: uploader,
                    onGallerySelected: {
                        navigationState = .gallery
                    }
                )
                .environmentObject(authenticator)
                .transition(.identity) // No transition animation
            }
            
            if navigationState == .gallery {
                GalleryView(
                    uploader: uploader,
                    authenticator: authenticator,
                    onBack: {
                        navigationState = .gallerySelection
                    }
                )
                .transition(.identity) // No transition animation
            }
        }
        .navigationTitle(navigationTitle)
        .applyNavigationSubtitle(navigationSubtitle)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .errorAlert() // Show error alerts from ErrorAlertManager
        .onAppear {
            setupNotificationObservers()
            
            // Check if tenant is already selected (e.g., from test token or restored session)
            if authenticator.tenant != nil {
                navigationState = .gallerySelection
            }
        }
        .onChange(of: uploader.selectedGallery) { _, newValue in
            // Sync navigation state with uploader state
            if newValue != nil && navigationState != .gallery {
                navigationState = .gallery
            } else if newValue == nil && navigationState == .gallery {
                navigationState = .gallerySelection
            }
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for workspace switch request from avatar menu
        NotificationCenter.default.addObserver(
            forName: .switchWorkspace,
            object: nil,
            queue: .main
        ) { [self] _ in
            self.forceShowWorkspaceSelection = true  // Always show the selection view
            self.navigationState = .workspaceSelection
        }
    }
}

