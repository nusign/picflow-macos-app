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
import Sentry

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
        // Initialize Sentry as early as possible (recommended by official guide)
        setupSentry()
        
        // Show dock icon - this is a regular app with menu bar icon for quick access
        NSApp.setActivationPolicy(.regular)
        
        // Setup menu bar status item
        menuBarManager.setup(action: #selector(toggleWindow), target: self)
        menuBarManager.observeUploader(uploader)
        
        // Setup settings manager (main actor isolated)
        Task { @MainActor in
            setupSettingsManager()
        }
        
        // Tenant loading is now handled by WorkspaceSelectionView
        // after user logs in via OAuth or selects a workspace
    }
    
    // MARK: - Sentry Setup
    
    /// Initialize Sentry error reporting (simple implementation following official guide)
    private func setupSentry() {
        SentrySDK.start { options in
            options.dsn = Constants.sentryDSN
            
            // Only enable debug in development
            #if DEBUG
            options.debug = true
            #endif
            
            // macOS-specific: Enable uncaught NSException reporting
            // The SDK can't capture these out of the box on macOS
            options.enableUncaughtNSExceptionReporting = true
            
            // Set environment
            options.environment = EnvironmentManager.shared.current.rawValue.lowercased()
            
            // Set release version for tracking
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "picflow-macos@\(version)+\(build)"
            }
        }
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
    
    /// Prevent app from quitting when main window is closed/hidden
    /// This allows the app to stay running in the menu bar
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
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
    @objc private func toggleWindow() {
        // Find the main app window, excluding menu bar windows and panels
        let mainWindow = NSApp.windows.first { window in
            window.canBecomeKey && 
            !window.className.contains("StatusBar") &&
            window.styleMask.contains(.titled)
        }
        
        guard let window = mainWindow else {
            // No main window found, activate app
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Simple toggle: if window is key, hide it. Otherwise, show it.
        if window.isKeyWindow {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}