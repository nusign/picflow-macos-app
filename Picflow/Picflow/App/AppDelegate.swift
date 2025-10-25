//
//  AppDelegate.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//


import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var floatingWindow: NSWindow!
    private var isAttached: Bool = true
    private var uploader: Uploader!
    private var authenticator: Authenticator!
    private var cancellables = Set<AnyCancellable>()
    private var windowMonitor: Any?
    private var isAnimating: Bool = false
    private var toolbar: NSToolbar?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize authenticator and uploader on the main actor
        Task { @MainActor in
            authenticator = Authenticator()
            uploader = Uploader()
            
            // Setup window and status item after uploader is initialized
            setupFloatingWindow()
            setupStatusItem()
            
            // Observe uploader state for menu bar updates
            uploader.objectWillChange.sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
            
            // When authenticated, load tenant details
            authenticator.$state
                .receive(on: RunLoop.main)
                .sink { [weak self] state in
                    guard let self = self else { return }
                    if case .authorized = state {
                        Task { @MainActor in
                            do {
                                try await self.authenticator.loadTenantDetails()
                                print("Tenant details loaded successfully")
                            } catch {
                                print("Failed to load tenant details:", error)
                            }
                        }
                    }
                }
                .store(in: &cancellables)
        }
        
        // Hide dock icon - this is a menu bar only app
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to use custom icon, fallback to SF Symbol
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Picflow")
            }
            
            // Add action to toggle window on click
            button.action = #selector(toggleWindow)
            button.target = self
        }
    }
    
    @MainActor
    private func setupFloatingWindow() {
        let contentView = ContentView(uploader: uploader, authenticator: authenticator)
        
        floatingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Modern macOS window styling
        floatingWindow.title = ""
        floatingWindow.titlebarAppearsTransparent = true
        floatingWindow.titleVisibility = .hidden
        
        // Create visual effect view with modern material
        let visualEffectView = NSVisualEffectView()
        // Modern materials for macOS 15 - better glass effect
        if #available(macOS 14.0, *) {
            visualEffectView.material = .hudWindow  // Modern frosted glass effect
        } else {
            visualEffectView.material = .popover
        }
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        
        // Embed SwiftUI content in visual effect view
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.addSubview(hostingView)
        
        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        ])
        
        floatingWindow.contentView = visualEffectView
        floatingWindow.isReleasedWhenClosed = false
        floatingWindow.level = .normal
        floatingWindow.isMovableByWindowBackground = true
        floatingWindow.delegate = self
        
        // Add toolbar for proper rounded corners
        setupToolbar()
        
        // Hide initially
        floatingWindow.orderOut(nil)
    }
    
    @MainActor
    private func setupToolbar() {
        // Create empty toolbar just for rounded corners
        toolbar = NSToolbar(identifier: "MainToolbar")
        toolbar?.displayMode = .iconOnly
        
        floatingWindow.toolbar = toolbar
        floatingWindow.toolbarStyle = .unified
    }
    
    @MainActor
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        
        switch uploader.uploadState {
        case .idle:
            // Try custom icon first, fallback to SF Symbol
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Picflow")
            }
            
        case .uploading:
            // Use SF Symbol for uploading state
            if let uploadingIcon = NSImage(named: "MenuBarIcon-Uploading") {
                button.image = uploadingIcon
            } else {
                button.image = NSImage(systemSymbolName: "arrow.up.circle", accessibilityDescription: "Uploading")
            }
            
        case .completed:
            // Use SF Symbol for success state
            if let successIcon = NSImage(named: "MenuBarIcon-Success") {
                button.image = successIcon
            } else {
                button.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: "Upload Complete")
            }
            
            // Reset to idle after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self = self else { return }
                Task { @MainActor in
                    if let customIcon = NSImage(named: "MenuBarIcon") {
                        self.statusItem.button?.image = customIcon
                    } else {
                        self.statusItem.button?.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Picflow")
                    }
                }
            }
            
        case .failed:
            // Use SF Symbol for failed state
            if let failedIcon = NSImage(named: "MenuBarIcon-Failed") {
                button.image = failedIcon
            } else {
                button.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Upload Failed")
            }
        }
    }
    
    @objc private func toggleWindow() {
        Task { @MainActor in
            if floatingWindow.isVisible {
                floatingWindow.orderOut(nil)
            } else {
                showWindow(attached: isAttached)
            }
        }
    }
    
    @MainActor
    private func showWindow(attached: Bool) {
        guard let button = statusItem.button else { return }
        
        if attached {
            // Position below menu bar icon
            let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
            let windowX = buttonFrame.midX - (floatingWindow.frame.width / 2)
            let windowY = buttonFrame.minY - floatingWindow.frame.height - 8
            
            floatingWindow.setFrameOrigin(NSPoint(x: windowX, y: windowY))
        }
        
        // Show/hide traffic lights based on attached state
        showTrafficLights(!attached)
        
        floatingWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Setup click-outside-to-close if attached
        if attached {
            setupClickOutsideMonitor()
        } else {
            removeClickOutsideMonitor()
        }
    }
    
    @MainActor
    private func showTrafficLights(_ show: Bool) {
        floatingWindow.standardWindowButton(.closeButton)?.isHidden = !show
        floatingWindow.standardWindowButton(.miniaturizeButton)?.isHidden = !show
        floatingWindow.standardWindowButton(.zoomButton)?.isHidden = !show
    }
    
    private func setupClickOutsideMonitor() {
        removeClickOutsideMonitor()
        
        windowMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isAttached else { return }
            
            if let window = self.floatingWindow,
               window.isVisible,
               !window.frame.contains(event.locationInWindow) {
                window.orderOut(nil)
                self.removeClickOutsideMonitor()
            }
        }
    }
    
    private func removeClickOutsideMonitor() {
        if let monitor = windowMonitor {
            NSEvent.removeMonitor(monitor)
            windowMonitor = nil
        }
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == floatingWindow,
              let button = statusItem.button,
              !isAnimating else { return }
        
        // Check if window is close to menu bar icon
        let buttonFrame = button.window?.convertToScreen(button.frame) ?? .zero
        let windowFrame = window.frame
        
        // Calculate distance from window to button
        let distance = abs(windowFrame.midX - buttonFrame.midX) + abs(windowFrame.maxY - buttonFrame.minY)
        
        // If dragged far enough, detach
        if distance > 100 && isAttached {
            isAttached = false
            removeClickOutsideMonitor()
            showTrafficLights(true)
            print("Window detached")
        }
        // If dragged close enough, re-attach with animation
        else if distance < 100 && !isAttached {
            isAttached = true
            isAnimating = true
            
            // Calculate snap position
            let windowX = buttonFrame.midX - (windowFrame.width / 2)
            let windowY = buttonFrame.minY - windowFrame.height - 8
            let targetOrigin = NSPoint(x: windowX, y: windowY)
            
            // Animate snap to position
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                context.allowsImplicitAnimation = true
                window.setFrameOrigin(targetOrigin)
            }, completionHandler: { [weak self] in
                self?.isAnimating = false
            })
            
            setupClickOutsideMonitor()
            showTrafficLights(false)
            print("Window attached - snapping to position")
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        removeClickOutsideMonitor()
    }
}
 
