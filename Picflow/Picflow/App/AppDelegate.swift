//
//  AppDelegate.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  This class manages the macOS app's lifecycle, window behavior,
//  and user interactions. It handles:
//  - Menu bar status item (shows upload status and provides quick window toggle)
//  - Main application window with modern macOS styling
//  - Reactive updates for upload state and authentication
//
//  The app shows both in the dock and menu bar, providing flexible access.
//
//  TODO: Consider refactoring into separate managers:
//  - MenuBarManager (status item, icon updates)
//  - WindowManager (window setup and visibility)
//  - This would reduce complexity and improve testability
//

import SwiftUI
import Combine

/// Main application delegate that coordinates the app window and menu bar integration
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSToolbarDelegate {
    
    // MARK: - Properties
    
    /// The menu bar icon that shows upload status and provides quick window access
    private var statusItem: NSStatusItem!
    
    /// The main application window that contains the SwiftUI content
    private var floatingWindow: NSWindow!
    
    /// Handles file upload operations
    private var uploader: Uploader!
    
    /// Manages authentication state and API requests
    private var authenticator: Authenticator!
    
    /// Combine subscriptions for reactive updates
    private var cancellables = Set<AnyCancellable>()
    
    /// Task for resetting menu bar icon after upload completes
    private var iconResetTask: DispatchWorkItem?
    
    // MARK: - Constants
    
    /// Configuration for menu bar icon state changes
    private enum IconResetDelay {
        /// How long to show "completed" icon before reverting to idle
        static let completed: TimeInterval = 3.0
    }
    
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
            setupStatusItem()
            
            // Observe uploader state changes to update menu bar icon
            // (shows different icons for idle/uploading/completed/failed states)
            uploader.objectWillChange.sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
            
            // When user authenticates, automatically load their tenant details
            // (workspace, galleries, etc.) and resize window
            authenticator.$state
                .receive(on: RunLoop.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    if case .authorized = state {
                        Task { @MainActor in
                            // Resize window for authenticated view and enable resizing
                            self.resizeWindow(toHeight: 380)
                            self.floatingWindow.styleMask.insert(.resizable)
                            
                            do {
                                try await self.authenticator.loadTenantDetails()
                                print("✅ Tenant details loaded successfully")
                            } catch {
                                print("❌ Failed to load tenant details:", error)
                            }
                        }
                    } else {
                        // Back to login - resize to login size and disable resizing
                        Task { @MainActor in
                            self.resizeWindow(toHeight: 320)
                            self.floatingWindow.styleMask.remove(.resizable)
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
    
    /// Creates the menu bar status item for upload status indication and quick access
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to use custom icon from Assets, fallback to SF Symbol if not found
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Picflow")
            }
            
            // When clicked, show/hide the window (convenient quick access)
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }
    
    /// Creates and configures the main floating window with modern macOS styling
    @MainActor
    private func setupFloatingWindow() {
        let contentView = ContentView(uploader: uploader, authenticator: authenticator)
        
        // Create window with full-size content view (content extends into title bar)
        // Start with login size (440x320), non-resizable until authenticated
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 320),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Modern borderless window style with transparent title bar
        floatingWindow.title = ""
        floatingWindow.titlebarAppearsTransparent = true
        floatingWindow.titleVisibility = .hidden
        
        // Create visual effect view for frosted glass background
        // Key: Use .withinWindow for proper glass effect (blurs the window's own content)
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow  // Frosted glass material
        visualEffectView.blendingMode = .withinWindow  // Creates proper glass effect
        visualEffectView.state = .active
        
        // Embed SwiftUI content inside the visual effect view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)
        
        // Make SwiftUI content fill the entire visual effect view
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        floatingWindow.contentView = visualEffectView
        floatingWindow.isReleasedWhenClosed = false  // Keep window in memory when closed
        floatingWindow.level = .normal               // Standard window level
        floatingWindow.delegate = self
        
        // Set window size constraints
        floatingWindow.minSize = NSSize(width: 440, height: 320)
        floatingWindow.maxSize = NSSize(width: 960, height: 720)
        
        // Disable autofocus behavior
        floatingWindow.autorecalculatesKeyViewLoop = false
        floatingWindow.initialFirstResponder = nil
        
        // Setup toolbar for modern styling
        setupWindowToolbar()
        
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
    
    // MARK: - Menu Bar Icon Management
    
    /// Updates the menu bar icon based on current upload state
    /// Called automatically when uploader.uploadState changes
    @MainActor
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        
        // Cancel any scheduled icon reset from previous state
        iconResetTask?.cancel()
        iconResetTask = nil
        
        switch uploader.uploadState {
        case .idle:
            setMenuBarIcon(
                button: button,
                customName: "MenuBarIcon",
                fallbackSymbol: "photo.on.rectangle",
                description: "Picflow"
            )
            
        case .uploading:
            setMenuBarIcon(
                button: button,
                customName: "MenuBarIcon-Uploading",
                fallbackSymbol: "arrow.up.circle",
                description: "Uploading"
            )
            
        case .completed:
            setMenuBarIcon(
                button: button,
                customName: "MenuBarIcon-Success",
                fallbackSymbol: "checkmark.circle.fill",
                description: "Upload Complete"
            )
            
            // Schedule automatic reset to idle icon after delay
            // Using DispatchWorkItem allows cancellation if state changes again
            let resetTask = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    guard let button = self.statusItem.button else { return }
                    self.setMenuBarIcon(
                        button: button,
                        customName: "MenuBarIcon",
                        fallbackSymbol: "photo.on.rectangle",
                        description: "Picflow"
                    )
                }
            }
            iconResetTask = resetTask
            DispatchQueue.main.asyncAfter(
                deadline: .now() + IconResetDelay.completed,
                execute: resetTask
            )
            
        case .failed:
            setMenuBarIcon(
                button: button,
                customName: "MenuBarIcon-Failed",
                fallbackSymbol: "xmark.circle.fill",
                description: "Upload Failed"
            )
        }
    }
    
    /// Helper method to set menu bar icon, preferring custom assets over SF Symbols
    /// - Parameters:
    ///   - button: The menu bar button to update
    ///   - customName: Name of custom icon in Assets.xcassets
    ///   - fallbackSymbol: SF Symbol name to use if custom icon not found
    ///   - description: Accessibility description for the icon
    @MainActor
    private func setMenuBarIcon(button: NSStatusBarButton, customName: String, fallbackSymbol: String, description: String) {
        if let customIcon = NSImage(named: customName) {
            button.image = customIcon
        } else {
            button.image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: description)
        }
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
    
    // MARK: - Window Sizing
    
    /// Smoothly resizes the window to the specified height while maintaining width
    /// - Parameter height: The new height for the window
    @MainActor
    private func resizeWindow(toHeight height: CGFloat) {
        let currentFrame = floatingWindow.frame
        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: currentFrame.origin.y + (currentFrame.height - height), // Adjust Y to keep top-left corner in place
            width: 440, // Fixed width
            height: height
        )
        
        floatingWindow.setFrame(newFrame, display: true, animate: true)
    }
}
