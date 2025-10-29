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
    let forceShowSelection: Bool
    
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if authenticator.availableTenants.isEmpty {
                emptyStateView
            } else {
                workspaceListView
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            fetchTenants()
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading workspaces...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Failed to Load Workspaces")
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                fetchTenants()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
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
        .frame(maxHeight: .infinity)
    }
    
    private var workspaceListView: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let profile = authenticator.state.authorizedProfile {
                    profileHeaderView(profile: profile)
                }
                
                workspaceCardsView
                
                createWorkspaceButton
            }
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 48)
        }
        .scrollIndicators(.automatic)
    }
    
    private func profileHeaderView(profile: Profile) -> some View {
        VStack(spacing: 8) {
            userAvatar(profile: profile)
            
            Text("Choose Workspace")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Signed in as: \(profile.email)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 20)
    }
    
    private func userAvatar(profile: Profile) -> some View {
        Group {
            if let avatarURL = profile.avatarUrl, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    avatarPlaceholder(initials: profile.initials)
                }
            } else {
                avatarPlaceholder(initials: profile.initials)
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
    }
    
    private func avatarPlaceholder(initials: String) -> some View {
        Circle()
            .fill(Color.accentColor.opacity(0.2))
            .overlay(
                Text(initials)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundColor(.accentColor)
            )
    }
    
    private var workspaceCardsView: some View {
        ForEach(authenticator.availableTenants, id: \.id) { tenant in
            WorkspaceCardView(
                tenant: tenant,
                isSelected: authenticator.tenant?.id == tenant.id
            ) {
                selectTenant(tenant)
            }
        }
    }
    
    private var createWorkspaceButton: some View {
        Button {
            openCreateWorkspacePage()
        } label: {
            Text("Create Workspace")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.top, 8)
    }
    
    // MARK: - Actions
    
    private func fetchTenants() {
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
        guard !forceShowSelection else {
            print("📋 Showing tenant selection (\(authenticator.availableTenants.count) available)")
            return
        }
        
        if let tenant = authenticator.tenant {
            print("♻️ Tenant already selected: \(tenant.name), proceeding to gallery")
            onTenantSelected()
            return
        }
        
        if authenticator.availableTenants.count == 1,
           let onlyTenant = authenticator.availableTenants.first {
            print("🏢 Only 1 tenant available, auto-selecting: \(onlyTenant.name)")
            selectTenant(onlyTenant)
            return
        }
        
        print("📋 Showing tenant selection (\(authenticator.availableTenants.count) available)")
    }
    
    private func selectTenant(_ tenant: Tenant) {
        authenticator.selectTenant(tenant)
        onTenantSelected()
    }
    
    private func openCreateWorkspacePage() {
        let baseURL = EnvironmentManager.shared.current.apiBaseURL.replacingOccurrences(of: "/api", with: "")
        let createWorkspaceURL = "\(baseURL)/a/workspaces/create"
        if let url = URL(string: createWorkspaceURL) {
            NSWorkspace.shared.open(url)
        }
    }
}