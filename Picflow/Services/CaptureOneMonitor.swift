//
//  CaptureOneMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import Foundation
import AppKit
import Combine
import Sentry

/// Monitors whether Capture One is currently running and reads selection data
class CaptureOneMonitor: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var selection: CaptureOneSelection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
    @Published var isLoadingSelection: Bool = false
    @Published var selectionError: String?
    @Published var needsPermission: Bool = false
    @Published var hasAttemptedPermission: Bool = false // Track if we've tried asking before
    
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private let scriptBridge = CaptureOneScriptBridge()
    
    // Possible bundle identifiers for Capture One
    // Note: Must match entitlements file (wildcards not supported)
    // Based on: https://en.wikipedia.org/wiki/Capture_One
    private let captureOneBundleIdentifiers = [
        // Current versions
        "com.captureone.captureone16",
        // Future versions
        "com.captureone.captureone17",
        "com.captureone.captureone18",
        "com.captureone.captureone19",
        "com.captureone.captureone20",
        // Past versions
        "com.captureone.captureone15",
        // Generic fallbacks
        "com.captureone.captureone"
    ]
    
    init() {
        // Check if we've previously attempted permission
        hasAttemptedPermission = UserDefaults.standard.bool(forKey: "CaptureOnePermissionAttempted")
        
        // If we haven't attempted permission yet, assume we need it
        // This blocks all AppleScript calls until user explicitly clicks "Allow Access"
        if !hasAttemptedPermission {
            needsPermission = true
            print("⚠️ First launch - blocking AppleScript until permission granted")
        }
        
        checkCaptureOneStatus()
        setupObservers()
    }
    
    deinit {
        cleanup()
    }
    
    private func setupObservers() {
        // Listen for application launch/terminate notifications
        workspaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.checkCaptureOneStatus()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.checkCaptureOneStatus()
        }
        
        // Listen for when our app becomes active (user might have granted permission in System Settings)
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recheckPermissionsIfNeeded()
        }
        
        // Poll every 2 seconds for status and selection
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkCaptureOneStatus()
            self?.updateSelection()
        }
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        
        if let observer = workspaceObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    /// Checks if Capture One is currently running
    private func checkCaptureOneStatus() {
        let runningApps = NSWorkspace.shared.runningApplications
        
        // Check by bundle identifier
        let isCaptureOneRunning = runningApps.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return captureOneBundleIdentifiers.contains(bundleId)
        }
        
        // If not found by bundle ID, try by app name as fallback
        let isCaptureOneRunningByName = runningApps.contains { app in
            guard let localizedName = app.localizedName else { return false }
            return localizedName.lowercased().contains("capture one")
        }
        
        let newStatus = isCaptureOneRunning || isCaptureOneRunningByName
        
        // Only update if status changed
        if newStatus != isRunning {
            self.isRunning = newStatus
            print("Capture One status changed: \(newStatus ? "Running" : "Not Running")")
        }
    }
    
    /// Force a manual check (async for immediate update)
    func refresh() async {
        checkCaptureOneStatus()
        
        // Don't trigger permission prompt on automatic refresh
        guard isRunning && !needsPermission else { return }
        
        do {
            let newSelection = try await scriptBridge.getSelection()
            await MainActor.run {
                self.selection = newSelection
                self.selectionError = nil
                self.needsPermission = false
                print("🔄 Manual refresh: '\(newSelection.documentName ?? "Unknown")' with \(newSelection.count) variant\(newSelection.count == 1 ? "" : "s")")
            }
        } catch {
            print("⚠️ Refresh failed: \(error)")
        }
    }
    
    /// Request automation permission (triggers the permission prompt)
    func requestPermission() {
        Task {
            do {
                let newSelection = try await scriptBridge.getSelection()
                // Success! Permission granted and got selection
                await MainActor.run {
                    self.selection = newSelection
                    self.selectionError = nil
                    self.needsPermission = false
                    self.hasAttemptedPermission = true
                    UserDefaults.standard.set(true, forKey: "CaptureOnePermissionAttempted")
                    print("✅ Permission granted!")
                }
            } catch CaptureOneScriptBridge.CaptureOneError.noDocument {
                // Permission was granted, but no document is open - this is OK!
                await MainActor.run {
                    self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                    self.selectionError = "No document open"
                    self.needsPermission = false
                    self.hasAttemptedPermission = true
                    UserDefaults.standard.set(true, forKey: "CaptureOnePermissionAttempted")
                    print("✅ Permission granted! (no documents open)")
                }
            } catch CaptureOneScriptBridge.CaptureOneError.permissionDenied {
                // User explicitly denied permission
                await MainActor.run {
                    self.needsPermission = true
                    self.hasAttemptedPermission = true
                    UserDefaults.standard.set(true, forKey: "CaptureOnePermissionAttempted")
                    print("❌ Permission denied by user")
                }
            } catch {
                // Other error - assume permission issue
                await MainActor.run {
                    self.needsPermission = true
                    self.hasAttemptedPermission = true
                    UserDefaults.standard.set(true, forKey: "CaptureOnePermissionAttempted")
                    print("❌ Permission error: \(error)")
                }
            }
        }
    }
    
    /// Open System Settings to the Privacy & Security → Automation page
    func openAutomationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        NSWorkspace.shared.open(url)
    }
    
    /// Re-check permissions when app becomes active (user might have granted permission in System Settings)
    private func recheckPermissionsIfNeeded() {
        // Only check if we currently need permission
        guard needsPermission else { return }
        
        // Only check if Capture One is running
        guard isRunning else { return }
        
        print("🔄 Re-checking permissions (app became active)...")
        
        Task {
            do {
                let newSelection = try await scriptBridge.getSelection()
                // Success! Permission was granted externally
                await MainActor.run {
                    self.selection = newSelection
                    self.selectionError = nil
                    self.needsPermission = false
                    print("✅ Permission detected (granted externally)")
                }
            } catch CaptureOneScriptBridge.CaptureOneError.noDocument {
                // Permission was granted, but no document is open
                await MainActor.run {
                    self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                    self.selectionError = "No document open"
                    self.needsPermission = false
                    print("✅ Permission detected (no documents open)")
                }
            } catch CaptureOneScriptBridge.CaptureOneError.permissionDenied {
                // Still denied
                print("⚠️ Permission still denied")
            } catch {
                // Other error - keep showing permission UI
                print("⚠️ Error checking permission: \(error)")
            }
        }
    }
    
    /// Update selection data from Capture One
    private func updateSelection() {
        // Skip polling if we need permission - only request when user clicks the button
        guard !needsPermission else {
            return
        }
        
        // Double-check if running right before making the call
        // This prevents a race condition where the app quits between timer ticks
        let runningApps = NSWorkspace.shared.runningApplications
        let isCaptureOneActuallyRunning = runningApps.contains { app in
            guard let bundleId = app.bundleIdentifier else { return false }
            return captureOneBundleIdentifiers.contains(bundleId)
        }
        
        guard isCaptureOneActuallyRunning && isRunning else {
            // Clear selection if not running
            DispatchQueue.main.async {
                self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                self.selectionError = nil
            }
            return
        }
        
        // Skip if already loading
        guard !isLoadingSelection else {
            print("⏸️ Skipping selection update - already loading")
            return
        }
        
        Task { @MainActor in
            isLoadingSelection = true
            selectionError = nil
            
            do {
                let newSelection = try await scriptBridge.getSelection()
                
                // Log changes in selection count or document name
                let countChanged = newSelection.count != self.selection.count
                let documentChanged = newSelection.documentName != self.selection.documentName
                
                if countChanged || documentChanged {
                    if countChanged && documentChanged {
                        print("🔄 Switched to '\(newSelection.documentName ?? "Unknown")': \(newSelection.count) variant\(newSelection.count == 1 ? "" : "s") selected")
                    } else if countChanged {
                        print("🔄 Selection changed: \(self.selection.count) → \(newSelection.count) variants")
                    } else if documentChanged {
                        print("🔄 Document switched: '\(self.selection.documentName ?? "Unknown")' → '\(newSelection.documentName ?? "Unknown")'")
                    }
                }
                
                // Always update selection (triggers @Published update)
                self.selection = newSelection
                self.selectionError = nil
                self.needsPermission = false
            } catch CaptureOneScriptBridge.CaptureOneError.noDocument {
                print("⚠️ No document open in Capture One")
                self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                self.selectionError = "No document open"
                self.needsPermission = false
            } catch CaptureOneScriptBridge.CaptureOneError.permissionDenied {
                print("⚠️ Permission denied for Capture One")
                self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                self.selectionError = nil
                self.needsPermission = true
            } catch CaptureOneScriptBridge.CaptureOneError.notRunning {
                print("⚠️ Capture One is not running")
                self.selection = CaptureOneSelection(count: 0, variants: [], documentName: nil)
                self.selectionError = nil
                self.needsPermission = false
                // Clear the running state since app is not actually running
                self.isRunning = false
            } catch {
                print("❌ Selection update error: \(error.localizedDescription)")
                self.selectionError = "Script error: \(error.localizedDescription)"
                self.needsPermission = false
            }
            
            isLoadingSelection = false
        }
    }
}

