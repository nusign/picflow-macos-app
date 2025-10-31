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
    @State private var showCreateGallerySheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                loadingView
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
                            // VStack(spacing: 4) {
                            //     // Workspace Indicator
                            //     if let tenant = authenticator.tenant {
                            //         HStack(spacing: 8) {
                            //             // Workspace favicon or initial
                            //             if let faviconUrl = tenant.faviconUrl, let url = URL(string: faviconUrl) {
                            //                 AsyncImage(url: url) { image in
                            //                     image
                            //                         .resizable()
                            //                         .aspectRatio(contentMode: .fill)
                            //                 } placeholder: {
                            //                     workspacePlaceholder(for: tenant)
                            //                 }
                            //                 .frame(width: 20, height: 20)
                            //                 .background(Color.white)
                            //                 .clipShape(RoundedRectangle(cornerRadius: 4))
                            //             } else {
                            //                 workspacePlaceholder(for: tenant)
                            //             }
                            //             
                            //             Text(tenant.name)
                            //                 .font(.system(size: 12, weight: .medium))
                            //                 .foregroundColor(.secondary)
                            //         }
                            //     }
                            // }
                            //.padding()
                            //.frame(maxWidth: .infinity)
                            
                            // Title and Create Button
                            HStack {
                                Text("Choose Gallery")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Button(action: {
                                    showCreateGallerySheet = true
                                }) {
                                    Text("Create Gallery")
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.extraLarge)
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                            
                            // Gallery list
                            VStack(spacing: 4) {
                                ForEach(galleries, id: \.id) { gallery in
                                    GalleryCardView(gallery: gallery) {
                                        uploader.selectGallery(gallery)
                                        // Track gallery selection
                                        AnalyticsManager.shared.trackGallerySelected(gallery: gallery)
                                        onGallerySelected()
                                    }
                                }
                            }
                            .padding(16)
                            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 32))
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
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Spacer() // Needed to avoid empty toolbar and show rounded corners
            }
            ToolbarItem(placement: .automatic) {
                AvatarToolbarButton(authenticator: authenticator)
            }
        }
        .sheet(isPresented: $showCreateGallerySheet) {
            CreateGallerySheet(
                uploader: uploader,
                onGalleryCreated: { gallery in
                    showCreateGallerySheet = false
                    uploader.selectGallery(gallery)
                    AnalyticsManager.shared.trackGallerySelected(gallery: gallery)
                    onGallerySelected()
                }
            )
        }
    }
    
    // MARK: - View Components
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading Galleries")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
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

// MARK: - Create Gallery Sheet

struct CreateGallerySheet: View {
    @ObservedObject var uploader: Uploader
    let onGalleryCreated: (GalleryDetails) -> Void
    @State private var galleryTitle = ""
    @State private var isCreating = false
    @State private var error: Error?
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Title
            Text("Create Gallery")
                .font(.title)
                .fontWeight(.bold)
            
            // Input Field
            TextField("Gallery Title", text: $galleryTitle)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .disabled(isCreating)
                .onSubmit {
                    Task {
                        await createGallery()
                    }
                }
            
            // Error Message
            if let error = error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            
            // Create Button
            Button(action: {
                Task {
                    await createGallery()
                }
            }) {
                if isCreating {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(galleryTitle.isEmpty || isCreating)
        }
        .padding(32)
        .frame(width: 400)
        .onAppear {
            isFocused = true
        }
    }
    
    private func createGallery() async {
        guard !galleryTitle.isEmpty else { return }
        
        isCreating = true
        error = nil
        
        do {
            let request = CreateGalleryRequest(title: galleryTitle, preset: "review")
            let gallery: GalleryDetails = try await Endpoint(
                path: "/v1/galleries",
                httpMethod: .post,
                requestBody: request
            ).response()
            
            // Success - navigate to uploader with new gallery
            await MainActor.run {
                onGalleryCreated(gallery)
            }
        } catch {
            await MainActor.run {
                self.error = error
                self.isCreating = false
            }
        }
    }
}
