//
//  AppDelegate.swift
//  Picflow Live
//
//  Created by Michel Luarasi on 26.01.2025.
//


import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: NSWindow!
    private var uploader: Uploader!
    private var authenticator: Authenticator!
    private var cancellables = Set<AnyCancellable>()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize authenticator and uploader on the main actor
        Task { @MainActor in
            authenticator = Authenticator()
            uploader = Uploader()
            
            // Setup window and status item after uploader is initialized
            setupWindow()
            setupStatusItem()
            
            // Observe uploader state for menu bar updates
            uploader.objectWillChange.sink { [weak self] _ in
                self?.updateMenuBarIcon()
            }
            .store(in: &cancellables)
            
            // Set authentication after initialization
            print("Setting hardcoded token...")
            authenticator.authenticate(token: Constants.hardcodedToken)
            Endpoint.currentTenantId = Constants.tenantId
            
            // Load tenant details after authentication
            print("Loading tenant details...")
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await authenticator.loadTenantDetails()
                print("Tenant details loaded successfully")
            } catch {
                print("Failed to load tenant details:", error)
            }
        }
        
        // Handle dock icon clicks
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            button.image = NSImage(named: "MenuBarIcon")
        }
        
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show/Hide Window", action: #selector(toggleWindow), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    private func setupWindow() {
        let contentView = ContentView(uploader: uploader, authenticator: authenticator)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: contentView)
        window.center()
        window.isReleasedWhenClosed = false
        window.title = "Picflow Live"
    }
    
    @MainActor
    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }
        
        switch uploader.uploadState {
        case .idle:
            button.image = NSImage(named: "MenuBarIcon")
        case .uploading:
            button.image = NSImage(named: "MenuBarIcon-Uploading")
        case .completed:
            button.image = NSImage(named: "MenuBarIcon-Success")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.statusItem.button?.image = NSImage(named: "MenuBarIcon")
            }
        case .failed:
            button.image = NSImage(named: "MenuBarIcon-Failed")
        }
    }
    
    @objc private func toggleWindow() {
        if window.isVisible {
            window.orderOut(nil)
        } else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
} 
