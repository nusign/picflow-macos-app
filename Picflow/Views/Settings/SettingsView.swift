//
//  SettingsView.swift
//  Picflow
//
//  App settings and preferences view
//

import SwiftUI
import IOKit

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var developerModeEnabled = DeveloperModeManager.shared.isEnabled
    @State private var clickCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Settings Content
            ScrollView {
                VStack(spacing: 24) {
                    // General Section
                    SettingsSection(title: "General") {
                        SettingsToggle(
                            icon: "menubar.rectangle",
                            title: "Show menu bar icon",
                            subtitle: "Show Picflow icon in the menu bar",
                            isOn: $settingsManager.showMenuBarIcon
                        )
                        
                        SettingsToggle(
                            icon: "power",
                            title: "Launch at startup",
                            subtitle: "Automatically launch Picflow on startup",
                            isOn: $settingsManager.launchAtLogin
                        )
                    }
                    
                    // Updates Section
                    SettingsSection(title: "Updates") {
                        SettingsToggle(
                            icon: "arrow.down.circle",
                            title: "Automatically update Picflow",
                            subtitle: "Keep Picflow up to date with the latest features",
                            isOn: $settingsManager.autoUpdate
                        )
                    }
                    
                    // Integration Section
                    SettingsSection(title: "Integration") {
                        SettingsToggleDisabled(
                            icon: "finder",
                            title: "Finder extension",
                            subtitle: "Right-click files in Finder to upload to Picflow",
                            badge: "Soon"
                        )
                        
                        SettingsPickerDisabled(
                            icon: "arrow.triangle.merge",
                            title: "Conflict behaviour",
                            subtitle: "Choose how to handle duplicate files in Finder",
                            selectedOption: "New File",
                            badge: "Soon"
                        )
                    }
                    
                    // Advanced Section
                    SettingsSection(title: "Advanced") {
                        SettingsButton(
                            icon: "doc.text",
                            title: "Open logs folder",
                            subtitle: "View app logs and debugging information",
                            action: {
                                settingsManager.openLogsFolder()
                            }
                        )
                    }
                    
                    // Developer Section - Hidden in production unless developer mode is enabled
                    #if DEBUG
                    SettingsSection(title: "Developer") {
                        DeveloperSectionContent()
                    }
                    #else
                    if developerModeEnabled {
                        SettingsSection(title: "Developer") {
                            DeveloperSectionContent(developerModeEnabled: $developerModeEnabled)
                        }
                    }
                    #endif
                    
                    // Hidden activation area - Click "Picflow" title 5 times to enable developer mode
                    #if !DEBUG
                    Color.clear
                        .frame(height: 1)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 5) {
                            DeveloperModeManager.shared.toggle()
                            developerModeEnabled = DeveloperModeManager.shared.isEnabled
                            
                            // Visual feedback
                            NSSound.beep()
                            
                            let alert = NSAlert()
                            alert.messageText = developerModeEnabled ? "Developer Mode Enabled" : "Developer Mode Disabled"
                            alert.informativeText = developerModeEnabled 
                                ? "Developer settings are now visible. Restart the app to hide them again."
                                : "Developer settings are now hidden."
                            alert.alertStyle = .informational
                            alert.runModal()
                        }
                    #endif
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
    }
    
    // MARK: - Helper Functions
    
    private func testSentry() {
        // Send a simple test message
        ErrorReportingManager.shared.captureMessage(
            "Test event from Picflow Settings",
            level: .info
        )
        
        // Send a test error
        let testError = NSError(
            domain: "com.picflow.test",
            code: 999,
            userInfo: [NSLocalizedDescriptionKey: "Test error to verify Sentry"]
        )
        ErrorReportingManager.shared.reportError(
            testError,
            tags: ["source": "settings_test"]
        )
        
        print("✅ Test events sent to Sentry")
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            VStack(spacing: 0) {
                content
            }
            .background(.thickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

// MARK: - Settings Toggle

struct SettingsToggle: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
        .padding(12)
    }
}

// MARK: - Settings Toggle (Disabled)

struct SettingsToggleDisabled: View {
    let icon: String
    let title: String
    let subtitle: String
    let badge: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: .constant(false))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(true)
        }
        .padding(12)
    }
}

// MARK: - Settings Picker (Disabled)

struct SettingsPickerDisabled: View {
    let icon: String
    let title: String
    let subtitle: String
    let selectedOption: String
    let badge: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(badge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Picker("", selection: .constant(selectedOption)) {
                Text(selectedOption).tag(selectedOption)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(true)
            .frame(width: 120)
        }
        .padding(12)
    }
}

// MARK: - Settings Button

struct SettingsButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.accentColor)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(isHovered ? Color.accentColor.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Developer Section Content

struct DeveloperSectionContent: View {
    var developerModeEnabled: Binding<Bool>? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            SettingsButton(
                icon: "ladybug",
                title: "Test Sentry",
                subtitle: "Send a test event to verify error reporting",
                action: {
                    // Send a simple test error
                    let testError = NSError(
                        domain: "com.picflow.test",
                        code: 999,
                        userInfo: [NSLocalizedDescriptionKey: "Test error from Settings"]
                    )
                    ErrorReportingManager.shared.reportError(
                        testError,
                        tags: ["source": "settings_test"]
                    )
                    print("✅ Test error sent to Sentry")
                }
            )
            
            #if !DEBUG
            if let developerModeBinding = developerModeEnabled {
                Divider()
                    .padding(.horizontal, 12)
                
                SettingsButton(
                    icon: "xmark.circle",
                    title: "Disable Developer Mode",
                    subtitle: "Hide developer settings",
                    action: {
                        DeveloperModeManager.shared.disable()
                        developerModeBinding.wrappedValue = false
                    }
                )
            }
            #endif
            
            Divider()
                .padding(.horizontal, 12)
            
            DeviceInfoRow()
        }
    }
}

// MARK: - Device Info Row

struct DeviceInfoRow: View {
    private let deviceID = DeveloperModeManager.getDeviceIdentifier()
    @State private var showCopiedFeedback = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Device ID")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(deviceID)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: copyDeviceID) {
                HStack(spacing: 4) {
                    Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                    Text(showCopiedFeedback ? "Copied" : "Copy")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(showCopiedFeedback ? .green : .accentColor)
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
    }
    
    private func copyDeviceID() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(deviceID, forType: .string)
        
        showCopiedFeedback = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showCopiedFeedback = false
        }
    }
}

// MARK: - Developer Mode Manager

class DeveloperModeManager {
    static let shared = DeveloperModeManager()
    
    private let storageKey = "\(Constants.bundleIdentifier).developerMode"
    
    var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: storageKey)
        #endif
    }
    
    func toggle() {
        #if !DEBUG
        let newValue = !isEnabled
        UserDefaults.standard.set(newValue, forKey: storageKey)
        print("🔧 Developer mode \(newValue ? "enabled" : "disabled")")
        #endif
    }
    
    func enable() {
        #if !DEBUG
        UserDefaults.standard.set(true, forKey: storageKey)
        print("🔧 Developer mode enabled")
        #endif
    }
    
    func disable() {
        #if !DEBUG
        UserDefaults.standard.set(false, forKey: storageKey)
        print("🔧 Developer mode disabled")
        #endif
    }
    
    /// Get a unique device identifier for whitelisting purposes
    static func getDeviceIdentifier() -> String {
        // Use hardware UUID - persists across app reinstalls
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        
        if platformExpert != 0 {
            if let serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String {
                IOObjectRelease(platformExpert)
                return serialNumberAsCFString
            }
            IOObjectRelease(platformExpert)
        }
        
        // Fallback to a stored UUID if hardware UUID is not available
        let fallbackKey = "\(Constants.bundleIdentifier).deviceUUID"
        if let stored = UserDefaults.standard.string(forKey: fallbackKey) {
            return stored
        }
        
        let newUUID = UUID().uuidString
        UserDefaults.standard.set(newUUID, forKey: fallbackKey)
        return newUUID
    }
}
