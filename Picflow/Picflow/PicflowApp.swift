import SwiftUI
// TODO: Add Sentry via Swift Package Manager before uncommenting
// Package URL: https://github.com/getsentry/sentry-cocoa
// import Sentry

@main
struct PicflowApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize Sentry for error reporting
        // TODO: Uncomment after adding Sentry SDK via Swift Package Manager
        /*
        SentrySDK.start { options in
            options.dsn = Constants.sentryDSN
            options.debug = false // Set to true for debugging Sentry itself
            options.enableAutoSessionTracking = true
            options.attachScreenshot = true
            options.environment = "production" // Change to "development" for dev builds
            
            // Performance monitoring (optional)
            options.tracesSampleRate = 1.0 // 100% of transactions for testing, reduce in production
            
            // Release tracking (optional, useful for tracking which version has errors)
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "\(version) (\(build))"
            }
        }
        */
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}