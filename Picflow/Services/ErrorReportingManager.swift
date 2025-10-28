//
//  ErrorReportingManager.swift
//  Picflow
//
//  Centralized error reporting service to simplify Sentry integration
//  Reduces boilerplate code and provides consistent error tracking across the app
//

import Foundation
import Sentry

/// Centralized error reporting manager for consistent error tracking
/// Note: Not @MainActor because Sentry SDK is thread-safe and can be called from any thread
class ErrorReportingManager {
    static let shared = ErrorReportingManager()
    
    private init() {}
    
    // MARK: - Error Reporting
    
    /// Report a simple error with minimal context
    func reportError(
        _ error: Error,
        message: String? = nil,
        level: SentryLevel = .error
    ) {
        SentrySDK.capture(error: error) { scope in
            if let message = message {
                scope.setContext(value: ["message": message], key: "error_info")
            }
            scope.setLevel(level)
        }
    }
    
    /// Report an error with operation context (most common pattern)
    func reportError(
        _ error: Error,
        operation: String,
        context: [String: Any] = [:],
        tags: [String: String] = [:],
        level: SentryLevel = .error
    ) {
        SentrySDK.capture(error: error) { scope in
            var fullContext = context
            fullContext["operation"] = operation
            
            scope.setContext(value: fullContext, key: operation)
            scope.setTag(value: operation, key: "operation")
            
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
            
            scope.setLevel(level)
        }
    }
    
    /// Report authentication-related errors
    func reportAuthError(
        _ error: Error,
        method: String,
        context: [String: Any] = [:]
    ) {
        SentrySDK.capture(error: error) { scope in
            var authContext = context
            authContext["auth_method"] = method
            
            scope.setContext(value: authContext, key: "auth")
            scope.setTag(value: method, key: "auth_method")
            scope.setLevel(.error)
        }
    }
    
    /// Report upload-related errors
    func reportUploadError(
        _ error: Error,
        fileName: String? = nil,
        fileSize: Int? = nil,
        galleryId: String? = nil,
        additionalContext: [String: Any] = [:]
    ) {
        SentrySDK.capture(error: error) { scope in
            var uploadContext = additionalContext
            
            if let fileName = fileName {
                uploadContext["file_name"] = fileName
            }
            if let fileSize = fileSize {
                uploadContext["file_size"] = fileSize
            }
            if let galleryId = galleryId {
                uploadContext["gallery_id"] = galleryId
            }
            
            scope.setContext(value: uploadContext, key: "upload")
            scope.setTag(value: "upload", key: "operation")
            
            if let galleryId = galleryId {
                scope.setTag(value: galleryId, key: "gallery_id")
            }
            
            scope.setLevel(.error)
        }
    }
    
    /// Report folder monitoring errors
    func reportFolderMonitorError(
        _ error: Error,
        folderPath: String,
        additionalContext: [String: Any] = [:]
    ) {
        SentrySDK.capture(error: error) { scope in
            var monitorContext = additionalContext
            monitorContext["folder_path"] = folderPath
            
            scope.setContext(value: monitorContext, key: "folder_monitor")
            scope.setTag(value: "folder_monitor", key: "operation")
            scope.setLevel(.error)
        }
    }
    
    // MARK: - Breadcrumbs
    
    /// Add a breadcrumb to track user actions
    func addBreadcrumb(
        _ message: String,
        category: String,
        level: SentryLevel = .info,
        data: [String: Any] = [:]
    ) {
        let breadcrumb = Breadcrumb(level: level, category: category)
        breadcrumb.message = message
        breadcrumb.data = data
        SentrySDK.addBreadcrumb(breadcrumb)
    }
    
    // MARK: - Messages
    
    /// Capture a message (for non-error events)
    func captureMessage(
        _ message: String,
        level: SentryLevel = .info,
        tags: [String: String] = [:],
        context: [String: Any] = [:]
    ) {
        SentrySDK.capture(message: message) { scope in
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
            
            if !context.isEmpty {
                scope.setContext(value: context, key: "message_info")
            }
            
            scope.setLevel(level)
        }
    }
    
    // MARK: - Testing
    
    /// Send test events to verify Sentry integration
    func sendTestEvents() {
        print("🧪 Sending test events to Sentry...")
        
        // Add a breadcrumb
        addBreadcrumb(
            "User triggered Sentry test",
            category: "test",
            data: ["timestamp": Date().description]
        )
        
        // Capture a test message
        captureMessage(
            "Test message from Picflow",
            level: .info,
            tags: ["source": "test"],
            context: [
                "test_type": "manual_trigger",
                "environment": EnvironmentManager.shared.current.rawValue
            ]
        )
        
        // Capture a test error
        let testError = NSError(
            domain: "com.picflow.test",
            code: 9999,
            userInfo: [NSLocalizedDescriptionKey: "Test error to verify Sentry integration"]
        )
        reportError(
            testError,
            operation: "test",
            context: [
                "test_type": "manual_trigger",
                "environment": EnvironmentManager.shared.current.rawValue
            ],
            tags: ["source": "test"],
            level: .warning
        )
        
        print("✅ Test events sent. Check console for debug output and Sentry dashboard.")
    }
}

