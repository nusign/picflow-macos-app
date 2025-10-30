//
//  AvatarToolbarButton.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

// MARK: - Navigation Notifications

extension Notification.Name {
    static let switchWorkspace = Notification.Name("com.picflow.switchWorkspace")
}

/// A toolbar button that displays a profile icon and triggers the profile menu
struct AvatarToolbarButton: View {
    @ObservedObject var authenticator: Authenticator
    @State private var showProfileMenu = false
    @State private var avatarImage: NSImage?
    
    private var profile: Profile? {
        if case .authorized(_, let profile) = authenticator.state {
            return profile
        }
        return nil
    }
    
    var body: some View {
        Button {
            showProfileMenu.toggle()
        } 
        label: {
            if let avatarImage = avatarImage {
                Image(nsImage: avatarImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .help("Account")
        .accessibilityLabel("Account")
        .popover(isPresented: $showProfileMenu, arrowEdge: .bottom) {
            if case .authorized(_, let profile) = authenticator.state {
                ProfileDropdownContent(profile: profile, authenticator: authenticator)
            }
        }
        .task(id: profile?.avatarUrl) {
            await loadAvatar()
        }
    }
    
    private func loadAvatar() async {
        guard let profile = profile,
              let avatarUrlString = profile.avatarUrl,
              let url = URL(string: avatarUrlString) else {
            avatarImage = nil
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let nsImage = NSImage(data: data) {
                await MainActor.run {
                    avatarImage = nsImage
                }
            }
        } catch {
            // Failed to load avatar, keep using placeholder
            await MainActor.run {
                avatarImage = nil
            }
        }
    }
}

/// The content of the profile dropdown menu
struct ProfileDropdownContent: View {
    let profile: Profile
    @ObservedObject var authenticator: Authenticator
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with larger avatar
            VStack(spacing: 12) {
                AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text("\(profile.firstName) \(profile.lastName)")
                        .font(.system(size: 14, weight: .semibold))
                    Text(profile.email)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            
            Divider()
            
            // Menu items
            VStack(spacing: 0) {
                ProfileMenuItem(icon: "arrow.up.forward.app", title: "Open Picflow") {
                    if let url = URL(string: "https://picflow.com/a/home") {
                        NSWorkspace.shared.open(url)
                    }
                }
                
                ProfileMenuItem(icon: "arrow.up.forward.app", title: "Profile Settings") {
                    if let url = URL(string: "https://picflow.com/a/settings/profile") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()
                    .padding(.vertical, 4)
                
                ProfileMenuItem(icon: "gear", title: "App Settings") {
                    Task { @MainActor in
                        SettingsWindowManager.shared.showSettings()
                    }
                    dismiss()
                }
                
                ProfileMenuItem(icon: "arrow.triangle.2.circlepath", title: "Switch Workspace") {
                    NotificationCenter.default.post(name: .switchWorkspace, object: nil)
                    dismiss()
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                ProfileMenuItem(icon: "rectangle.portrait.and.arrow.right", title: "Logout", isDestructive: true) {
                    authenticator.logout()
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: 240)
        // .background(.regularMaterial)
        .focusable(false) // Disable autofocus in popover
    }
}

/// A single menu item in the profile dropdown
struct ProfileMenuItem: View {
    let icon: String
    let title: String
    var isDestructive: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(isDestructive ? .red : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .focusable(false) // Prevent focus ring on menu items
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


