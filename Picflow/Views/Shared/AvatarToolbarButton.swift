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
    
    var body: some View {
        Group {
            if case .authorized(_, let profile) = authenticator.state {
                Button(action: {
                    showProfileMenu.toggle()
                }) {
                    AsyncImage(url: URL(string: profile.avatarUrl ?? "")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(width: 32, height: 32)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                        case .failure:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                        @unknown default:
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showProfileMenu, arrowEdge: .bottom) {
                    ProfileDropdownContent(profile: profile, authenticator: authenticator)
                }
            } else {
                // Hide button completely when not authenticated (e.g., on login view)
                EmptyView()
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
        .background(.regularMaterial)
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

