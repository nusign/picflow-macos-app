//
//  SettingsView.swift
//  Picflow
//
//  App settings and preferences view
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold))
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .padding(.bottom, 0)
            
            // Settings Content
            ScrollView {
                VStack(spacing: 24) {
                    // General Section
                    SettingsSection(title: "General") {
                        SettingsToggle(
                            icon: "menubar.rectangle",
                            title: "Show menu bar icon",
                            subtitle: "Display Picflow icon in the menu bar",
                            isOn: $settingsManager.showMenuBarIcon
                        )
                        
                        SettingsToggle(
                            icon: "power",
                            title: "Launch at login",
                            subtitle: "Automatically start Picflow when you log in",
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
                            icon: "folder",
                            title: "Finder extension",
                            subtitle: "Right-click files to upload to Picflow",
                            badge: "Soon"
                        )
                        
                        SettingsToggleDisabled(
                            icon: "arrow.triangle.merge",
                            title: "Conflict behaviour",
                            subtitle: "Choose how to handle duplicate files",
                            badge: "Soon"
                        )
                    }
                    
                    // Advanced Section
                    SettingsSection(title: "Advanced") {
                        SettingsButton(
                            icon: "doc.text",
                            title: "Open logs folder",
                            subtitle: "View application logs and debugging information",
                            action: {
                                settingsManager.openLogsFolder()
                            }
                        )
                    }
                }
                .padding(24)
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
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
            .background(Color(NSColor.controlBackgroundColor))
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

