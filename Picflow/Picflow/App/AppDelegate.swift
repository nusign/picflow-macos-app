//
//  AppDelegate.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  This class manages the macOS app's lifecycle and menu bar integration.
//  The window is now managed by SwiftUI's WindowGroup for a modern,
//  native SwiftUI experience.
//

import SwiftUI
import Combine

/// Main application delegate that coordinates menu bar integration and core services
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    /// Manages the menu bar status item
    private var menuBarManager = MenuBarManager()
    
    /// Handles file upload operations - exposed for SwiftUI WindowGroup
    let uploader: Uploader
    
    /// Manages authentication state and API requests - exposed for SwiftUI WindowGroup
    let authenticator: Authenticator
    
    /// Combine subscriptions for reactive updates
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    @MainActor
    override init() {
        // Initialize core services before any views are created
        // This prevents flickering caused by late initialization
        authenticator = Authenticator()
        uploader = Uploader()
        
        super.init()
    }
    
    // MARK: - Application Lifecycle
    
    /// Called when the application finishes launching
    /// Sets up menu bar integration and authentication observers
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Show dock icon - this is a regular app with menu bar icon for quick access
        NSApp.setActivationPolicy(.regular)
        
        // Setup menu bar status item
        menuBarManager.setup(action: #selector(toggleWindow), target: self)
        menuBarManager.observeUploader(uploader)
        
        // Setup settings manager (main actor isolated)
        Task { @MainActor in
            setupSettingsManager()
        }
        
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
    }
    
    /// Called when the user clicks the dock icon
    /// SwiftUI WindowGroup automatically handles window visibility
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // If no visible windows, let SwiftUI create/show one
        if !flag {
            // Find and activate the main window
            NSApp.activate(ignoringOtherApps: true)
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    /// Sets up settings manager and its integrations
    @MainActor
    private func setupSettingsManager() {
        let settings = SettingsManager.shared
        
        // Handle menu bar icon visibility changes
        settings.setMenuBarIconChangeHandler { [weak self] show in
            Task { @MainActor in
                self?.menuBarManager.setVisible(show)
            }
        }
        
        // Apply initial state
        menuBarManager.setVisible(settings.showMenuBarIcon)
        
        // Clean old logs on startup
        settings.cleanOldLogs()
    }
    
    // MARK: - Window Visibility Management
    
    /// Toggles window visibility when menu bar icon is clicked
    /// SwiftUI WindowGroup manages the window, so we just activate the app
    @objc private func toggleWindow() {
        // Get the main window from SwiftUI's WindowGroup
        if let window = NSApp.windows.first(where: { $0.isVisible }) {
            // Window is visible, hide it
            window.orderOut(nil)
        } else if let window = NSApp.windows.first {
            // Window exists but hidden, show it
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            // No window, activate app to let SwiftUI create one
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
