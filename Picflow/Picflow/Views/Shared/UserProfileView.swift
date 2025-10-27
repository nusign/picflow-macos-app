//
//  UserProfileView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct UserProfileView: View {
    let profile: Profile
    @ObservedObject var authenticator: Authenticator
    @State private var showingDropdown = false
    
    var body: some View {
        Button(action: {
            showingDropdown.toggle()
        }) {
            AsyncImage(url: avatarURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.accentColor.opacity(0.3))
                    .overlay(
                        Text(initials)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.accentColor)
                    )
            }
            .frame(width: 32, height: 32)
            .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingDropdown, arrowEdge: .bottom) {
            UserDropdownView(
                profile: profile,
                authenticator: authenticator,
                onClose: { showingDropdown = false }
            )
        }
    }
    
    private var avatarURL: URL? {
        guard let urlString = profile.avatarUrl else { return nil }
        return URL(string: urlString)
    }
    
    private var initials: String {
        let first = profile.firstName.prefix(1)
        let last = profile.lastName.prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

struct UserDropdownView: View {
    let profile: Profile
    @ObservedObject var authenticator: Authenticator
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with large avatar and user info
            VStack(spacing: 8) {
                AsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.accentColor.opacity(0.3))
                        .overlay(
                            Text(initials)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.accentColor)
                        )
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                
                Text(profile.fullName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(profile.email)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity)
            
            Divider()
            
            // Menu items
            VStack(spacing: 0) {
                DropdownMenuItem(
                    icon: "arrow.up.forward.app",
                    title: "Open Picflow",
                    action: {
                        if let url = URL(string: "https://picflow.com") {
                            NSWorkspace.shared.open(url)
                        }
                        onClose()
                    }
                )
                
                DropdownMenuItem(
                    icon: "gearshape",
                    title: "Account Settings",
                    action: {
                        if let url = URL(string: "https://picflow.com/settings") {
                            NSWorkspace.shared.open(url)
                        }
                        onClose()
                    }
                )
                
                Divider()
                    .padding(.vertical, 4)
                
                DropdownMenuItem(
                    icon: "arrow.left.arrow.right",
                    title: "Switch Workspace",
                    action: {
                        // TODO: Implement workspace switching
                        print("Switch workspace tapped")
                        onClose()
                    }
                )
                
                DropdownMenuItem(
                    icon: "rectangle.portrait.and.arrow.right",
                    title: "Logout",
                    action: {
                        authenticator.logout()
                        onClose()
                    }
                )
            }
            .padding(.vertical, 8)
        }
        .frame(width: 260)
        .background(.regularMaterial)
    }
    
    private var avatarURL: URL? {
        guard let urlString = profile.avatarUrl else { return nil }
        return URL(string: urlString)
    }
    
    private var initials: String {
        let first = profile.firstName.prefix(1)
        let last = profile.lastName.prefix(1)
        return "\(first)\(last)".uppercased()
    }
}

struct DropdownMenuItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
