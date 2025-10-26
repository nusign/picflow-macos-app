//
//  SettingsWindowManager.swift
//  Picflow
//
//  Manages the Settings window presentation
//

import SwiftUI
import AppKit

class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    
    private var settingsWindow: NSWindow?
    
    private init() {}
    
    @MainActor
    func showSettings() {
        // If window already exists, just bring it to front
        if let existingWindow = settingsWindow {
            existingWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        // Create settings view
        let settingsView = SettingsView()
            .environmentObject(SettingsManager.shared)
        
        let hostingController = NSHostingController(rootView: settingsView)
        
        // Create window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        window.contentViewController = hostingController
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        
        // Make it a utility panel (stays on top, but not intrusive)
        window.level = .floating
        
        self.settingsWindow = window
        
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    func closeSettings() {
        settingsWindow?.close()
        settingsWindow = nil
    }
}

