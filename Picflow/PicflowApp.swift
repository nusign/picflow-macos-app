import SwiftUI
import AppKit
import Sparkle
import OSLog

// MARK: - Logger

private let logger = Logger(subsystem: "com.picflow.macos", category: "Sparkle")

// MARK: - Sparkle Updater Delegate

private class SparkleUpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        logger.info("✅ Sparkle: Appcast loaded successfully")
        logger.info("Sparkle: Found \(appcast.items.count) items in appcast")
        for item in appcast.items {
            logger.info("Sparkle: Version \(item.displayVersionString)")
        }
    }
    
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        logger.info("✅ Sparkle: Found valid update: \(item.displayVersionString)")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        logger.info("Sparkle: No updates found (app is up to date)")
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        logger.error("❌ Sparkle: Update aborted with error: \(error.localizedDescription)")
        logger.error("Sparkle: Error details: \(String(describing: error))")
    }
    
    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        logger.error("❌ Sparkle: Failed to download update: \(error.localizedDescription)")
    }
}

// MARK: - Sparkle Check for Updates View

private struct CheckForUpdatesView: View {
    @ObservedObject private var checkForUpdatesViewModel: CheckForUpdatesViewModel
    
    init(updater: SPUUpdater) {
        self.checkForUpdatesViewModel = CheckForUpdatesViewModel(updater: updater)
    }
    
    var body: some View {
        Button("Check for Updates...") {
            checkForUpdatesViewModel.checkForUpdates()
        }
        .disabled(!checkForUpdatesViewModel.canCheckForUpdates)
    }
}

private final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false
    
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
        
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
        
        // Log initial state
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            logger.info("CheckForUpdatesViewModel: canCheckForUpdates = \(self.canCheckForUpdates)")
            if !self.canCheckForUpdates {
                logger.warning("⚠️ Sparkle: Cannot check for updates - button is disabled")
                logger.info("This usually means:")
                logger.info("  - App is not properly code-signed")
                logger.info("  - Running from Xcode (development mode)")
                logger.info("  - Sparkle framework is not properly embedded")
                logger.info("  - Info.plist is missing required keys")
            }
        }
    }
    
    func checkForUpdates() {
        logger.info("User triggered manual update check")
        logger.info("canCheckForUpdates: \(self.canCheckForUpdates)")
        
        if self.canCheckForUpdates {
            logger.info("Calling updater.checkForUpdates()...")
            updater.checkForUpdates()
        } else {
            logger.error("❌ Cannot check for updates - Sparkle is not ready")
        }
    }
}

// MARK: - Window Configurator

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
    
    // Sparkle updater controller and delegate
    private let updaterController: SPUStandardUpdaterController
    private let updaterDelegate = SparkleUpdaterDelegate()
    
    init() {
        logger.info("🚀 Initializing Picflow App")
        
        // Log bundle information for debugging
        if let bundleID = Bundle.main.bundleIdentifier {
            logger.info("Bundle ID: \(bundleID)")
        }
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            logger.info("App Version: \(version)")
        }
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            logger.info("Build Number: \(build)")
        }
        
        // Log Sparkle configuration
        if let feedURL = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String {
            logger.info("Sparkle Feed URL: \(feedURL)")
        } else {
            logger.error("❌ Sparkle: SUFeedURL not found in Info.plist!")
        }
        
        if let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String {
            logger.info("Sparkle Public Key: \(publicKey.prefix(20))...")
        } else {
            logger.error("❌ Sparkle: SUPublicEDKey not found in Info.plist!")
        }
        
        // Initialize Sparkle updater with delegate
        logger.info("Initializing Sparkle updater...")
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )
        
        // Log updater state (capture controller locally to avoid capturing mutating self)
        let controller = updaterController
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            logger.info("Sparkle updater can check for updates: \(controller.updater.canCheckForUpdates)")
            logger.info("Sparkle updater automatically checks for updates: \(controller.updater.automaticallyChecksForUpdates)")
            logger.info("Sparkle updater automatically downloads updates: \(controller.updater.automaticallyDownloadsUpdates)")
            
            // Check if running in development mode
            #if DEBUG
            logger.warning("⚠️ Running in DEBUG mode - Sparkle may not work properly")
            #endif
            
            // Check code signing
            if let executableURL = Bundle.main.executableURL {
                logger.info("Executable path: \(executableURL.path)")
            }
        }
        
        // Initialize analytics for user tracking and events
        Task { @MainActor in
            AnalyticsManager.shared.initialize()
        }
        
        // Sentry is now initialized in AppDelegate.applicationDidFinishLaunching
        // (recommended by official guide for earliest possible initialization)
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

                // System-aligned window configuration for macOS 26 look
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)

                // Ensure the window allows vibrancy/translucency
                window.isOpaque = false
                window.backgroundColor = .clear
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
            
            // Add Check for Updates menu command
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
    }
}

