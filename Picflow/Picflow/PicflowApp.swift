import SwiftUI
// TODO: Add Sentry via Swift Package Manager before uncommenting
// Package URL: https://github.com/getsentry/sentry-cocoa
// import Sentry

import AppKit

private struct WindowConfigurator: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private extension View {
    func onNSWindow(_ configure: @escaping (NSWindow) -> Void) -> some View {
        background(WindowConfigurator(configure: configure))
    }
}

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
        Window("Picflow", id: "main") {
            ContentView(
                uploader: appDelegate.uploader,
                authenticator: appDelegate.authenticator
            )
            .frame(minWidth: 480, maxWidth: 720, minHeight: 400, maxHeight: 640)
            .onNSWindow { window in
                // Allow dragging the window by clicking and dragging in background areas
                window.isMovableByWindowBackground = true
            }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 480, height: 400)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .commands {
            // Add Settings menu command
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowManager.shared.showSettings()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}
