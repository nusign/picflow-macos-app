//
//  MenuBarManager.swift
//  Picflow
//
//  Manages the menu bar status item and icon updates
//

import AppKit
import Combine

/// Manages the menu bar status item, showing upload state and providing quick window access
class MenuBarManager {
    
    // MARK: - Properties
    
    /// The menu bar icon that shows upload status
    private var statusItem: NSStatusItem!
    
    /// Task for resetting menu bar icon after upload completes
    private var iconResetTask: DispatchWorkItem?
    
    /// Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private enum IconResetDelay {
        /// How long to show "completed" icon before reverting to idle
        static let completed: TimeInterval = 3.0
    }
    
    // MARK: - Setup
    
    /// Creates and configures the menu bar status item
    /// - Parameter action: Selector to call when the menu bar icon is clicked
    /// - Parameter target: Target object for the action
    func setup(action: Selector, target: AnyObject) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Try to use custom icon from Assets, fallback to SF Symbol if not found
            if let customIcon = NSImage(named: "MenuBarIcon") {
                button.image = customIcon
            } else {
                button.image = NSImage(systemSymbolName: "photo.on.rectangle", accessibilityDescription: "Picflow")
            }
            
            // When clicked, toggle window visibility
            button.action = action
            button.target = target
        }
    }
    
    /// Observes uploader state changes and updates the menu bar icon accordingly
    /// - Parameter uploader: The uploader instance to observe
    func observeUploader(_ uploader: Uploader) {
        uploader.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.updateIcon(for: uploader.uploadState)
            }
        }
        .store(in: &cancellables)
    }
    
    /// Controls the visibility of the menu bar icon
    /// - Parameter visible: Whether the icon should be visible
    @MainActor
    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }
    
    // MARK: - Icon Updates
    
    /// Updates the menu bar icon based on upload state
    /// - Parameter state: The current upload state
    @MainActor
    private func updateIcon(for state: UploadState) {
        guard let button = statusItem.button else { return }
        
        // Cancel any scheduled icon reset from previous state
        iconResetTask?.cancel()
        iconResetTask = nil
        
        switch state {
        case .idle:
            setIcon(
                button: button,
                customName: "MenuBarIcon",
                fallbackSymbol: "photo.on.rectangle",
                description: "Picflow"
            )
            
        case .uploading:
            setIcon(
                button: button,
                customName: "MenuBarIcon-Uploading",
                fallbackSymbol: "arrow.up.circle",
                description: "Uploading"
            )
            
        case .completed:
            setIcon(
                button: button,
                customName: "MenuBarIcon-Success",
                fallbackSymbol: "checkmark.circle.fill",
                description: "Upload Complete"
            )
            
            // Schedule automatic reset to idle icon after delay
            let resetTask = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    guard let button = self?.statusItem.button else { return }
                    self?.setIcon(
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
            setIcon(
                button: button,
                customName: "MenuBarIcon-Failed",
                fallbackSymbol: "xmark.circle.fill",
                description: "Upload Failed"
            )
        }
    }
    
    /// Helper method to set menu bar icon, preferring custom assets over SF Symbols
    @MainActor
    private func setIcon(button: NSStatusBarButton, customName: String, fallbackSymbol: String, description: String) {
        if let customIcon = NSImage(named: customName) {
            button.image = customIcon
        } else {
            button.image = NSImage(systemSymbolName: fallbackSymbol, accessibilityDescription: description)
        }
    }
}

