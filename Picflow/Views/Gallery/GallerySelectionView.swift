//
//  GallerySelectionView.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import SwiftUI

struct GallerySelectionView: View {
    @ObservedObject var uploader: Uploader
    @EnvironmentObject var authenticator: Authenticator
    let onGallerySelected: () -> Void
    @State private var galleries: [GalleryDetails] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("Loading galleries...")
                Spacer()
            } else if let error = error {
                Spacer()
                VStack {
                    Text("Error loading galleries")
                        .foregroundColor(.red)
                    Text(error.localizedDescription)
                        .font(.caption)
                    Button("Retry") {
                        Task {
                            await loadGalleries()
                        }
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                            // Header inside ScrollView
                            VStack(spacing: 4) {
                                // Workspace Indicator
                                if let tenant = authenticator.tenant {
                                    HStack(spacing: 8) {
                                        // Workspace favicon or initial
                                        if let faviconUrl = tenant.faviconUrl, let url = URL(string: faviconUrl) {
                                            AsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                            } placeholder: {
                                                workspacePlaceholder(for: tenant)
                                            }
                                            .frame(width: 20, height: 20)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        } else {
                                            workspacePlaceholder(for: tenant)
                                        }
                                        
                                        Text(tenant.name)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                // Title
                                HStack {
                                    Spacer()
                                    Text("Choose Gallery")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            
                            // Gallery list
                            ForEach(galleries, id: \.id) { gallery in
                                GalleryCardView(gallery: gallery) {
                                    uploader.selectGallery(gallery)
                                    // Track gallery selection
                                    AnalyticsManager.shared.trackGallerySelected(gallery: gallery)
                                    onGallerySelected()
                                }
                            }
                    }
                    .frame(maxWidth: 480)
                    .padding(.vertical, 48)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity) // Center the container
                }
                .scrollIndicators(.automatic)
            }
        }
        .frame(maxWidth: .infinity) // Ensure outer VStack takes full width
        .task {
            await loadGalleries()
        }
    }
    
    private func loadGalleries() async {
        isLoading = true
        error = nil
        
        do {
            let response: GalleryResponse = try await Endpoint(
                path: "/v1/galleries",
                httpMethod: .get,
                queryItems: [
                    "limit": "24",
                    "sort[]": "-last_changed_at"
                ]
            ).response()
            
            galleries = response.data
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
    
    @ViewBuilder
    private func workspacePlaceholder(for tenant: Tenant) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(0.2))
            
            // Show initial letter of workspace name
            Text(String(tenant.name.prefix(1)).uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.accentColor)
        }
        .frame(width: 20, height: 20)
    }
}
