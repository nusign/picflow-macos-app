//
//  ErrorAlertManager.swift
//  Picflow
//
//  Centralized error alert management for user-facing error messages
//

import Foundation
import SwiftUI
import AppKit
import os.log

/// Manages user-facing error alerts throughout the app
@MainActor
class ErrorAlertManager: ObservableObject {
    static let shared = ErrorAlertManager()
    
    /// Current error to display
    @Published var currentError: UserFacingError?
    
    /// Unified logging for better Console.app visibility
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.picflow", category: "errors")
    
    private init() {}
    
    /// Show an error alert to the user
    func showError(
        title: String,
        message: String,
        error: Error? = nil,
        context: ErrorContext = .general
    ) {
        // Log to unified logging system (shows up in Console.app)
        // This is better than print() for production apps
        if let error = error {
            logger.error("❌ \(title): \(message) - Details: \(error.localizedDescription)")
        } else {
            logger.error("❌ \(title): \(message)")
        }
        
        // Also print for Xcode console during development
        #if DEBUG
        print("❌ ERROR: \(title)")
        print("   Message: \(message)")
        if let error = error {
            print("   Details: \(error)")
        }
        #endif
        
        // Report to Sentry
        if let error = error {
            ErrorReportingManager.shared.reportError(
                error,
                context: ["user_message": message, "title": title],
                tags: ["error_context": context.rawValue, "user_facing": "true"]
            )
        }
        
        // Create user-facing error
        let userError = UserFacingError(
            title: title,
            message: message,
            underlyingError: error,
            context: context
        )
        
        // Show alert
        currentError = userError
    }
    
    /// Show a native NSAlert (useful for critical errors or when SwiftUI alert isn't appropriate)
    func showNativeAlert(
        title: String,
        message: String,
        style: NSAlert.Style = .warning
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Show a native NSAlert with custom action buttons
    /// - Parameters:
    ///   - title: Alert title
    ///   - message: Alert message
    ///   - primaryButton: Title for primary button
    ///   - secondaryButton: Title for secondary button (optional)
    ///   - style: Alert style
    ///   - primaryAction: Action to execute when primary button is tapped
    func showAlertWithAction(
        title: String,
        message: String,
        primaryButton: String,
        secondaryButton: String = "Cancel",
        style: NSAlert.Style = .warning,
        primaryAction: @escaping () async -> Void
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = style
        alert.addButton(withTitle: primaryButton)
        alert.addButton(withTitle: secondaryButton)
        
        let response = alert.runModal()
        
        // Primary button returns .alertFirstButtonReturn
        if response == .alertFirstButtonReturn {
            Task { @MainActor in
                await primaryAction()
            }
        }
    }
    
    /// Dismiss current error
    func dismissError() {
        currentError = nil
    }
}

// MARK: - User Facing Error Model

struct UserFacingError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let underlyingError: Error?
    let context: ErrorContext
    let timestamp = Date()
    
    var detailedMessage: String {
        if let error = underlyingError {
            return "\(message)\n\nTechnical details: \(error.localizedDescription)"
        }
        return message
    }
}

// MARK: - Error Context

enum ErrorContext: String {
    case general = "general"
    case upload = "upload"
    case authentication = "authentication"
    case captureOne = "capture_one"
    case folderMonitoring = "folder_monitoring"
    case network = "network"
}

// MARK: - SwiftUI Extension for Error Alerts

extension View {
    /// Automatically show error alerts from ErrorAlertManager
    func errorAlert() -> some View {
        self.modifier(ErrorAlertModifier())
    }
}

struct ErrorAlertModifier: ViewModifier {
    @ObservedObject var errorManager = ErrorAlertManager.shared
    
    func body(content: Content) -> some View {
        content
            .alert(
                errorManager.currentError?.title ?? "Error",
                isPresented: Binding(
                    get: { errorManager.currentError != nil },
                    set: { if !$0 { errorManager.dismissError() } }
                ),
                presenting: errorManager.currentError
            ) { error in
                Button("OK") {
                    errorManager.dismissError()
                }
            } message: { error in
                Text(error.message)
            }
    }
}

// MARK: - Helper Extensions

extension ErrorAlertManager {
    /// Helper for upload errors
    func showUploadError(fileName: String, error: Error) {
        showError(
            title: "Upload Failed",
            message: "Failed to upload \(fileName). Please try again.",
            error: error,
            context: .upload
        )
    }
    
    /// Helper for authentication errors
    func showAuthenticationError(message: String, error: Error? = nil) {
        showError(
            title: "Authentication Failed",
            message: message,
            error: error,
            context: .authentication
        )
    }
    
    /// Helper for Capture One errors
    func showCaptureOneError(message: String, error: Error? = nil) {
        showError(
            title: "Capture One Error",
            message: message,
            error: error,
            context: .captureOne
        )
    }
    
    /// Helper for folder monitoring errors
    func showFolderMonitoringError(message: String, error: Error? = nil) {
        showError(
            title: "Folder Monitoring Error",
            message: message,
            error: error,
            context: .folderMonitoring
        )
    }
    
    /// Helper for network errors
    func showNetworkError(message: String, error: Error? = nil) {
        showError(
            title: "Network Error",
            message: message,
            error: error,
            context: .network
        )
    }
}

