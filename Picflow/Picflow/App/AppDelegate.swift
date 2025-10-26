//
//  AppDelegate.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  This class manages the macOS app's lifecycle, window behavior,
//  and user interactions. It handles:
//  - Main application window with modern macOS styling
//  - Reactive updates for authentication
//
//  The app shows both in the dock and menu bar, providing flexible access.
//

import SwiftUI
import Combine

/// Main application delegate that coordinates the app window and menu bar integration
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    
    // MARK: - Properties
    
    /// Manages the menu bar status item
    private var menuBarManager = MenuBarManager()
    
    /// The main application window that contains the SwiftUI content
    private var floatingWindow: NSWindow!
    
    /// Handles file upload operations
    private var uploader: Uploader!
    
    /// Manages authentication state and API requests
    private var authenticator: Authenticator!
    
    /// Combine subscriptions for reactive updates
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Application Lifecycle
    
    /// Called when the application finishes launching
    /// Sets up the window, menu bar icon, and reactive data bindings, then shows the window
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize authenticator and uploader on the main actor
        Task { @MainActor in
            authenticator = Authenticator()
            uploader = Uploader()
            
            // Setup window and status item after dependencies are initialized
            setupFloatingWindow()
            menuBarManager.setup(action: #selector(toggleWindow), target: self)
            menuBarManager.observeUploader(uploader)
            
            // When user authenticates, automatically load their tenant details
            // (workspace, galleries, etc.)
            authenticator.$state
                .receive(on: RunLoop.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    if case .authorized = state {
                        Task { @MainActor in
                            do {
                                try await self.authenticator.loadTenantDetails()
                                print("✅ Tenant details loaded successfully")
                            } catch {
                                print("❌ Failed to load tenant details:", error)
                            }
                        }
                    }
                }
                .store(in: &cancellables)
            
            // Show window on launch
            showWindow()
        }
        
        // Show dock icon - this is a regular app with menu bar icon for quick access
        NSApp.setActivationPolicy(.regular)
    }
    
    // MARK: - Setup Methods
    
    /// Creates and configures the main floating window with modern macOS styling
    @MainActor
    private func setupFloatingWindow() {
        let contentView = ContentView(uploader: uploader, authenticator: authenticator)
        
        // Create window with full-size content view (content extends into title bar)
        // Start with minimum size, fully resizable
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Modern borderless window style with transparent title bar
        floatingWindow.title = ""
        floatingWindow.titlebarAppearsTransparent = true
        floatingWindow.titleVisibility = .hidden
        
        // Set SwiftUI content as window content directly
        let hostingView = NSHostingView(rootView: contentView)
        floatingWindow.contentView = hostingView
        floatingWindow.isReleasedWhenClosed = false  // Keep window in memory when closed
        floatingWindow.delegate = self
        
        // Disable auto-focus on first button
        floatingWindow.autorecalculatesKeyViewLoop = false
        floatingWindow.initialFirstResponder = nil
        
        // Set window size constraints
        floatingWindow.minSize = NSSize(width: 480, height: 400)
        floatingWindow.maxSize = NSSize(width: 720, height: 640)
        
        // Setup toolbar for modern styling
        setupWindowToolbar()
        
        // Center window on screen
        floatingWindow.center()
        
        // Start hidden - will be shown after initialization completes
        floatingWindow.orderOut(nil)
    }
    
    /// Sets up toolbar with avatar button for modern window styling
    /// (rounded corners and proper traffic light positioning)
    @MainActor
    private func setupWindowToolbar() {
        // Add toolbar - this enables macOS Big Sur+ rounded corners
        // and lets the system handle traffic light positioning automatically
        let toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.showsBaselineSeparator = false
        
        floatingWindow.toolbar = toolbar
        floatingWindow.toolbarStyle = .unified
        floatingWindow.titlebarSeparatorStyle = .none
    }
    
    // MARK: - NSToolbarDelegate
    
    private enum ToolbarIdentifier {
        static let avatarItem = NSToolbarItem.Identifier("AvatarItem")
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == ToolbarIdentifier.avatarItem {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            
            // Create a hosting view that contains the profile button
            // Uses default toolbar button styling
            let hostingView = NSHostingView(rootView: 
                AvatarToolbarButton(authenticator: authenticator)
            )
            
            item.view = hostingView
            
            return item
        }
        return nil
    }
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, ToolbarIdentifier.avatarItem]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, ToolbarIdentifier.avatarItem]
    }
    
    // MARK: - Window Visibility Management
    
    /// Toggles window visibility when menu bar icon is clicked
    @objc private func toggleWindow() {
        Task { @MainActor in
            if floatingWindow.isVisible {
                floatingWindow.orderOut(nil)
            } else {
                showWindow()
            }
        }
    }
    
    /// Shows and activates the window
    @MainActor
    private func showWindow() {
        floatingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
