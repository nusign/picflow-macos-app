//
//  WorkspaceSelectionView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct WorkspaceSelectionView: View {
    @ObservedObject var authenticator: Authenticator
    let onTenantSelected: () -> Void
    let forceShowSelection: Bool  // If true, never auto-skip (e.g., from "Switch Workspace" button)
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                // Loading state
                Spacer()
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading workspaces...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else if let errorMessage = errorMessage {
                // Error state
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Failed to Load Workspaces")
                        .font(.headline)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Try Again") {
                        fetchTenants()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else if authenticator.availableTenants.isEmpty {
                // No tenants found
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "building.2.crop.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Workspaces Found")
                        .font(.headline)
                    
                    Text("Please contact support to get access to a workspace.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                // Tenant list with Create button at bottom
                ScrollView {
                    VStack(spacing: 12) {
                        // Header with avatar and user info
                        if let profile = authenticator.state.authorizedProfile {
                            VStack(spacing: 8) {
                                // User avatar
                                if let avatarURL = profile.avatarUrl, let url = URL(string: avatarURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Circle()
                                            .fill(Color.accentColor.opacity(0.2))
                                            .overlay(
                                                Text(profile.initials)
                                                    .font(.system(size: 36, weight: .medium))
                                                    .foregroundColor(.accentColor)
                                            )
                                    }
                                    .frame(width: 96, height: 96)
                                    .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.accentColor.opacity(0.2))
                                        .overlay(
                                            Text(profile.initials)
                                                .font(.system(size: 36, weight: .medium))
                                                .foregroundColor(.accentColor)
                                        )
                                        .frame(width: 96, height: 96)
                                }
                                
                                // Title
                                Text("Choose Workspace")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                // Signed in as
                                Text("Signed in as: \(profile.email)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 20)
                        }
                        
                        // Workspace list
                        ForEach(authenticator.availableTenants, id: \.id) { tenant in
                            WorkspaceCard(
                                tenant: tenant,
                                isSelected: authenticator.tenant?.id == tenant.id
                            ) {
                                selectTenant(tenant)
                            }
                        }
                        
                        // Create Workspace button (at end of list, not sticky)
                        Button {
                            // Open web app to create workspace
                            let baseURL = EnvironmentManager.shared.current.apiBaseURL.replacingOccurrences(of: "/api", with: "")
                            let createWorkspaceURL = "\(baseURL)/a/workspaces/create"
                            if let url = URL(string: createWorkspaceURL) {
                                NSWorkspace.shared.open(url)
                            }
                        } label: {
                            Text("Create Workspace")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.bottom, 48)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity) // Center the container
                }
            }
        }
        .frame(maxWidth: .infinity) // Ensure outer VStack takes full width
        .onAppear {
            fetchTenants()
        }
    }
    
    private func fetchTenants() {
        // Tenants should already be loaded during login
        guard authenticator.availableTenants.isEmpty else {
            checkAutoSelect()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await authenticator.fetchAvailableTenants()
                await MainActor.run {
                    checkAutoSelect()
                }
            } catch {
                errorMessage = error.localizedDescription
                print("❌ Failed to fetch tenants:", error)
            }
            isLoading = false
        }
    }
    
    private func checkAutoSelect() {
        // Auto-proceed logic (only if NOT forced to show selection)
        guard !forceShowSelection else {
            print("📋 Showing tenant selection (\(authenticator.availableTenants.count) available)")
            return
        }
        
        // Case 1: Tenant already selected (from test token)
        if authenticator.tenant != nil {
            print("♻️ Tenant already selected, proceeding to gallery")
            onTenantSelected()
            return
        }
        
        // Case 2: Only 1 tenant available, auto-select it
        if authenticator.availableTenants.count == 1,
           let onlyTenant = authenticator.availableTenants.first {
            print("🏢 Only 1 tenant, auto-selecting: \(onlyTenant.name)")
            selectTenant(onlyTenant)
            return
        }
        
        // Otherwise: Show selection UI (multiple tenants)
        print("📋 Showing tenant selection (\(authenticator.availableTenants.count) available)")
    }
    
    private func selectTenant(_ tenant: Tenant) {
        authenticator.selectTenant(tenant)
        onTenantSelected()
    }
}

// MARK: - Workspace Card

struct WorkspaceCard: View {
    let tenant: Tenant
    let isSelected: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Favicon or placeholder with initial (with border when selected)
                Group {
                    if let faviconUrl = tenant.faviconUrl, let url = URL(string: faviconUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            placeholderIcon
                        }
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        placeholderIcon
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                
                // Tenant info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tenant.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        // Show "Guest" badge for shared tenants
                        if tenant.isShared {
                            Text("Guest")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.orange)
                                )
                        }
                    }
                    
                    Text("\(tenant.path).picflow.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Always show chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 16, weight: .semibold))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(isHovered ? 1.0 : 0.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var placeholderIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.2))
            
            // Show initial letter of workspace name
            Text(String(tenant.name.prefix(1)).uppercased())
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .frame(width: 48, height: 48)
    }
}