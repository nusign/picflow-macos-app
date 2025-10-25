//
//  CaptureOneMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import Foundation
import AppKit
import Combine
// TODO: Uncomment after adding Sentry SDK
// import Sentry

/// Monitors whether Capture One is currently running and reads selection data
class CaptureOneMonitor: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var selection: CaptureOneSelection = CaptureOneSelection(count: 0, variants: [])
    @Published var isLoadingSelection: Bool = false
    @Published var selectionError: String?
    @Published var needsPermission: Bool = false
    
    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private let scriptBridge = CaptureOneScriptBridge()
    
    // Possible bundle identifiers for Capture One
    private let captureOneBundleIdentifiers = [
        "com.captureone.captureone16",  // Current version (16.x)
        "com.captureone.captureone15",
        "com.captureone.captureone",
        "com.phaseone.captureone"
    ]
    
    init() {
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
            DispatchQueue.main.async {
                self.isRunning = newStatus
                print("Capture One status changed: \(newStatus ? "Running" : "Not Running")")
            }
        }
    }
    
    /// Force a manual check
    func refresh() {
        checkCaptureOneStatus()
        updateSelection()
    }
    
    /// Request automation permission (triggers the permission prompt)
    func requestPermission() {
        Task {
            do {
                _ = try await scriptBridge.getSelection()
            } catch {
                // Permission prompt will have appeared
                print("Permission request result: \(error)")
            }
        }
    }
    
    /// Update selection data from Capture One
    private func updateSelection() {
        guard isRunning else {
            // Clear selection if not running
            DispatchQueue.main.async {
                self.selection = CaptureOneSelection(count: 0, variants: [])
                self.selectionError = nil
            }
            return
        }
        
        // Skip if already loading
        guard !isLoadingSelection else { return }
        
        Task { @MainActor in
            isLoadingSelection = true
            selectionError = nil
            
            do {
                let newSelection = try await scriptBridge.getSelection()
                self.selection = newSelection
                self.selectionError = nil
                self.needsPermission = false
            } catch CaptureOneScriptBridge.CaptureOneError.noDocument {
                self.selection = CaptureOneSelection(count: 0, variants: [])
                self.selectionError = "No document open"
                self.needsPermission = false
            } catch CaptureOneScriptBridge.CaptureOneError.permissionDenied {
                self.selection = CaptureOneSelection(count: 0, variants: [])
                self.selectionError = nil
                self.needsPermission = true
                
                // TODO: Uncomment after adding Sentry SDK
                /*
                SentrySDK.capture(message: "Capture One permission denied") { scope in
                    scope.setLevel(.warning)
                    scope.setTag(value: "capture_one", key: "integration")
                }
                */
            } catch CaptureOneScriptBridge.CaptureOneError.notRunning {
                self.selection = CaptureOneSelection(count: 0, variants: [])
                self.selectionError = nil
                self.needsPermission = false
            } catch {
                self.selectionError = "Script error: \(error.localizedDescription)"
                self.needsPermission = false
                
                // Report unexpected Capture One errors to Sentry
                // TODO: Uncomment after adding Sentry SDK
                /*
                SentrySDK.capture(error: error) { scope in
                    scope.setContext(value: [
                        "is_running": isRunning,
                        "error_message": error.localizedDescription
                    ], key: "capture_one")
                    scope.setTag(value: "capture_one", key: "integration")
                }
                */
            }
            
            isLoadingSelection = false
        }
    }
}

