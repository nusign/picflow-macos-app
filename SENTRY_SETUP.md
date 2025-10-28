# Sentry Setup - Simplified

This document describes the simplified Sentry error reporting setup following the official [Sentry Cocoa guide](https://github.com/getsentry/sentry-cocoa).

## Initialization

Sentry is initialized in `AppDelegate.applicationDidFinishLaunching()` as recommended by the official guide:

```swift
private func setupSentry() {
    SentrySDK.start { options in
        options.dsn = Constants.sentryDSN
        
        // Only enable debug in development
        #if DEBUG
        options.debug = true
        #endif
        
        // macOS-specific: Enable uncaught NSException reporting
        // The SDK can't capture these out of the box on macOS
        options.enableUncaughtNSExceptionReporting = true
        
        // Set environment
        options.environment = EnvironmentManager.shared.current.rawValue.lowercased()
        
        // Set release version for tracking
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            options.releaseName = "picflow-macos@\(version)+\(build)"
        }
    }
}
```

### Key Changes from Previous Implementation

1. **Moved initialization** from `PicflowApp.init()` to `AppDelegate.applicationDidFinishLaunching()` (official recommendation)
2. **Debug mode is conditional** - only enabled in DEBUG builds, not in production
3. **Added macOS-specific setting** - `enableUncaughtNSExceptionReporting = true` (required for macOS apps)
4. **Removed complexity** - no performance monitoring, session tracking, or profiling
5. **Kept essentials** - environment and release tracking for better error organization

## Using ErrorReportingManager

The `ErrorReportingManager` provides simple wrapper methods for common operations:

### Report an Error

```swift
ErrorReportingManager.shared.reportError(
    error,
    context: ["key": "value"],
    tags: ["operation": "upload"]
)
```

### Capture a Message

```swift
ErrorReportingManager.shared.captureMessage(
    "Something interesting happened",
    level: .info
)
```

### Add Breadcrumbs

```swift
ErrorReportingManager.shared.addBreadcrumb(
    "User clicked upload button",
    category: "user_action",
    data: ["button_id": "upload"]
)
```

## Direct Sentry SDK Usage

You can also use the Sentry SDK directly - it's simple enough:

```swift
import Sentry

// Report an error
SentrySDK.capture(error: error) { scope in
    scope.setTag(value: "upload", key: "operation")
    scope.setContext(value: ["file": "photo.jpg"], key: "upload_info")
}

// Capture a message
SentrySDK.capture(message: "Test message")

// Add a breadcrumb
let breadcrumb = Breadcrumb(level: .info, category: "navigation")
breadcrumb.message = "User navigated to settings"
SentrySDK.addBreadcrumb(breadcrumb)
```

## Testing

Test Sentry integration from **Settings → Developer → Test Sentry**

This sends a test error to verify the connection is working.

## Resources

- [Official Sentry Cocoa Documentation](https://docs.sentry.io/platforms/apple/)
- [Sentry Cocoa GitHub](https://github.com/getsentry/sentry-cocoa)

