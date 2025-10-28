import SwiftUI
import Sentry
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
        // Initialize analytics for user tracking and events
        Task { @MainActor in
            AnalyticsManager.shared.initialize()
        }
        
        // Initialize Sentry for error reporting
        SentrySDK.start { options in
            options.dsn = Constants.sentryDSN
            options.debug = true // Set to true for debugging Sentry itself
            options.enableAutoSessionTracking = true
            options.attachStacktrace = true // Attach stack traces to all events
            
            // Set environment based on EnvironmentManager
            let environment = EnvironmentManager.shared.current
            options.environment = environment.rawValue.lowercased()
            
            // Performance monitoring (optional)
            options.tracesSampleRate = 0.1 // 10% of transactions, reduce overhead
            
            // Release tracking (useful for tracking which version has errors)
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
               let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                options.releaseName = "picflow-macos@\(version)+\(build)"
            }
        }
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
