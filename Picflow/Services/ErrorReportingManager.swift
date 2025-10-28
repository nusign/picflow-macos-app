//
//  ErrorReportingManager.swift
//  Picflow
//
//  Simplified error reporting service for Sentry integration
//  Provides lightweight convenience methods without over-engineering
//

import Foundation
import Sentry

/// Simplified error reporting manager
/// Note: Not @MainActor because Sentry SDK is thread-safe and can be called from any thread
class ErrorReportingManager {
    static let shared = ErrorReportingManager()
    
    private init() {}
    
    // MARK: - Basic Error Reporting
    
    /// Report an error with optional context
    func reportError(
        _ error: Error,
        context: [String: Any] = [:],
        tags: [String: String] = [:]
    ) {
        SentrySDK.capture(error: error) { scope in
            // Add context if provided
            if !context.isEmpty {
                scope.setContext(value: context, key: "error_context")
            }
            
            // Add tags if provided
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
        }
    }
    
    // MARK: - Messages
    
    /// Capture a message (for non-error events)
    func captureMessage(
        _ message: String,
        level: SentryLevel = .info
    ) {
        SentrySDK.capture(message: message) { scope in
            scope.setLevel(level)
        }
    }
    
    // MARK: - Breadcrumbs
    
    /// Add a breadcrumb to track user actions
    func addBreadcrumb(
        _ message: String,
        category: String = "default",
        level: SentryLevel = .info,
        data: [String: Any] = [:]
    ) {
        let breadcrumb = Breadcrumb(level: level, category: category)
        breadcrumb.message = message
        if !data.isEmpty {
            breadcrumb.data = data
        }
        SentrySDK.addBreadcrumb(breadcrumb)
    }
}
