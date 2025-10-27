//
//  SettingsView.swift
//  Picflow
//
//  App settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var environmentManager = EnvironmentManager.shared
    
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
                    
                    SettingsSection(title: "Developer") {
                        EnvironmentPicker(selectedEnvironment: $environmentManager.current)
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 500)
        .background(.regularMaterial)
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

// MARK: - Environment Picker

struct EnvironmentPicker: View {
    @Binding var selectedEnvironment: AppEnvironment
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .font(.system(size: 16))
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("API Environment")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(environmentSubtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Picker("", selection: $selectedEnvironment) {
                ForEach(AppEnvironment.allCases, id: \.self) { env in
                    Text(env.rawValue).tag(env)
                }
            }
            .labelsHidden()
            .frame(width: 140)
        }
        .padding(12)
    }
    
    private var environmentSubtitle: String {
        switch selectedEnvironment {
        case .development:
            return "dev.picflow.com"
        case .production:
            return "picflow.com"
        }
    }
}
