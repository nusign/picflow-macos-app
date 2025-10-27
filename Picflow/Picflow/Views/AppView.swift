//
//  AppView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI
import AppKit

// MARK: - Debug Environment Keys

// For feature-specific views (UploaderView, GallerySelectionView, etc.)
// Shortcut: D
private struct ShowDebugBordersKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

// For core app structure (AppView, ContentView, navigation)
// Shortcut: C
private struct ShowCoreDebugBordersKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var showDebugBorders: Bool {
        get { self[ShowDebugBordersKey.self] }
        set { self[ShowDebugBordersKey.self] = newValue }
    }
    
    var showCoreDebugBorders: Bool {
        get { self[ShowCoreDebugBordersKey.self] }
        set { self[ShowCoreDebugBordersKey.self] = newValue }
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
    @State private var navigationState: AppNavigationState = .workspaceSelection
    @State private var forceShowWorkspaceSelection: Bool = false // True when user explicitly clicks "Switch Workspace"
    @State private var showDebugBorders: Bool = false // D - Feature borders
    @State private var showCoreDebugBorders: Bool = false // C - Core borders
    @State private var eventMonitor: Any? = nil // Store event monitor reference
    
    var body: some View {
        // Main Navigation Content
        // Avatar is overlaid at top-right, stays fixed during navigation
        ZStack {
            if navigationState == .workspaceSelection {
                WorkspaceSelectionView(
                    authenticator: authenticator,
                    onWorkspaceSelected: {
                        navigationState = .gallerySelection
                        forceShowWorkspaceSelection = false // Reset after selection
                    },
                    forceShowSelection: forceShowWorkspaceSelection
                )
                .border(showCoreDebugBorders ? Color.blue : Color.clear, width: 2) // DEBUG: Workspace view boundary
                .transition(.identity) // No transition animation
            }
            
            if navigationState == .gallerySelection {
                GallerySelectionView(
                    uploader: uploader,
                    onGallerySelected: {
                        navigationState = .uploader
                    }
                )
                .environmentObject(authenticator)
                .border(showCoreDebugBorders ? Color.green : Color.clear, width: 2) // DEBUG: Gallery view boundary
                .transition(.identity) // No transition animation
            }
            
            if navigationState == .uploader {
                UploaderView(
                    uploader: uploader,
                    authenticator: authenticator,
                    onBack: {
                        navigationState = .gallerySelection
                    }
                )
                .border(showCoreDebugBorders ? Color.green : Color.clear, width: 2) // DEBUG: Uploader view boundary
                .transition(.identity) // No transition animation
            }
        }
        .border(showCoreDebugBorders ? Color.pink : Color.clear, width: 5) // DEBUG: Outer ZStack boundary
        .overlay(alignment: .topTrailing) {
            // Avatar button stays fixed in top-right corner across all views
            AvatarToolbarButton(authenticator: authenticator)
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .environment(\.showDebugBorders, showDebugBorders) // Pass feature debug state to child views
        .environment(\.showCoreDebugBorders, showCoreDebugBorders) // Pass core debug state to child views
        .onAppear {
            setupKeyboardShortcut()
            setupNotificationObservers()
            
            // Check if tenant is already selected (e.g., from test token or restored session)
            if authenticator.tenant != nil {
                navigationState = .gallerySelection
            }
        }
        .onDisappear {
            // Clean up event monitor when view disappears
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }
        .onChange(of: uploader.selectedGallery) { _, newValue in
            // Sync navigation state with uploader state
            if newValue != nil && navigationState != .uploader {
                navigationState = .uploader
            } else if newValue == nil && navigationState == .uploader {
                navigationState = .gallerySelection
            }
        }
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func setupKeyboardShortcut() {
        // Store the event monitor so it stays alive
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Debug: Print key events to troubleshoot
            print("⌨️ Key: \(event.charactersIgnoringModifiers ?? "nil")")
            
            // D - Toggle feature-specific borders (current view/file)
            if event.charactersIgnoringModifiers == "d" {
                Task { @MainActor in
                    self.showDebugBorders.toggle()
                    print("🔲 Feature Debug Borders (D): \(self.showDebugBorders ? "ON" : "OFF")")
                }
                return nil // Consume the event
            }
            
            // C - Toggle core app structure borders
            if event.charactersIgnoringModifiers == "c" {
                Task { @MainActor in
                    self.showCoreDebugBorders.toggle()
                    print("🔲 Core Debug Borders (C): \(self.showCoreDebugBorders ? "ON" : "OFF")")
                }
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
            self.forceShowWorkspaceSelection = true  // Always show the selection view
            self.navigationState = .workspaceSelection
        }
    }
}

