//
//  AppView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI
import AppKit

// MARK: - Debug Environment Key

private struct ShowDebugBordersKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var showDebugBorders: Bool {
        get { self[ShowDebugBordersKey.self] }
        set { self[ShowDebugBordersKey.self] = newValue }
    }
}

enum AppNavigationState {
    case workspaceSelection  // Future: when no workspace selected
    case gallerySelection    // When workspace selected but no gallery
    case uploader            // When gallery selected
}

struct AppView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    @State private var navigationState: AppNavigationState = .gallerySelection
    @State private var showDebugBorders: Bool = false
    
    var body: some View {
        // Main Navigation Content with Transitions
        // Note: Avatar is now in the window toolbar, not overlaid here
        ZStack {
            if navigationState == .workspaceSelection {
                WorkspaceSelectionView(
                    authenticator: authenticator,
                    onWorkspaceSelected: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            navigationState = .gallerySelection
                        }
                    }
                )
                .border(showDebugBorders ? Color.blue : Color.clear, width: 2) // DEBUG: Workspace view boundary
                .transition(.asymmetric(
                    insertion: .opacity,
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
            
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
                .border(showDebugBorders ? Color.green : Color.clear, width: 2) // DEBUG: Gallery view boundary
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
                .border(showDebugBorders ? Color.green : Color.clear, width: 2) // DEBUG: Uploader view boundary
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
            }
        }
        .border(showDebugBorders ? Color.pink : Color.clear, width: 5) // DEBUG: Outer ZStack boundary
        .frame(minWidth: 440, minHeight: 380)
        .background(Color.clear) // Transparent to show visual effect view
        .environment(\.showDebugBorders, showDebugBorders) // Pass debug state to child views
        .onAppear {
            setupKeyboardShortcut()
            setupNotificationObservers()
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
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Check for 'B' key (with or without modifiers)
            if event.charactersIgnoringModifiers == "b" {
                showDebugBorders.toggle()
                print("🔲 Debug borders: \(showDebugBorders ? "ON" : "OFF")")
                return nil // Consume the event
            }
            return event // Pass through other events
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
            withAnimation(.easeInOut(duration: 0.3)) {
                self.navigationState = .workspaceSelection
            }
        }
    }
}

