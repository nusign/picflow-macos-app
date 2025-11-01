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
    @State private var showGalleryOptionsSheet = false
    @State private var selectedSorting: SortingOption = .lastModified
    @State private var selectedPreset: PresetOption = .presetA
    
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
                    VStack(spacing: 24) {
                        // Responsive Grid Layout
                        // Uses adaptive GridItem to automatically create 2-4 columns
                        // based on card min/max width constraints
                        let spacing: CGFloat = 16
                        
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 240, maximum: 360), spacing: spacing)
                            ],
                            alignment: .leading,
                            spacing: spacing
                        ) {
                            ForEach(galleries, id: \.id) { gallery in
                                GalleryCardView(gallery: gallery) {
                                    uploader.selectGallery(gallery)
                                    // Track gallery selection
                                    AnalyticsManager.shared.trackGallerySelected(gallery: gallery)
                                    onGallerySelected()
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 24)
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
                Spacer()
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showGalleryOptionsSheet.toggle()
                }) {
                    Image(systemName: "ellipsis")
                }
                .help("More Options")
                .popover(isPresented: $showGalleryOptionsSheet, arrowEdge: .bottom) {
                    GalleryOptionsSheet(
                        selectedSorting: $selectedSorting,
                        selectedPreset: $selectedPreset
                    )
                }
            }
            
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    showCreateGallerySheet = true
                }) {
                    Text("Create Gallery")
                }
                .applyButtonStyle()
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
}

// MARK: - Sorting and Preset Options

enum SortingOption: String, CaseIterable {
    case lastModified = "Last Modified"
    case dateCreated = "Date Created"
    case alphabetical = "Alphabetical"
}

enum PresetOption: String, CaseIterable {
    case presetA = "Preset A"
    case presetB = "Preset B"
    case presetC = "Preset C"
}

// MARK: - Gallery Options Sheet

struct GalleryOptionsSheet: View {
    @Binding var selectedSorting: SortingOption
    @Binding var selectedPreset: PresetOption
    
    var body: some View {
        VStack(spacing: 0) {
            // Sorting Section Title
            HStack {
                Text("Sorting")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            // Sorting Options
            GalleryMenuItem(icon: selectedSorting == .lastModified ? "checkmark" : "", title: "Last Modified") {
                selectedSorting = .lastModified
            }
            
            GalleryMenuItem(icon: selectedSorting == .dateCreated ? "checkmark" : "", title: "Date Created") {
                selectedSorting = .dateCreated
            }
            
            GalleryMenuItem(icon: selectedSorting == .alphabetical ? "checkmark" : "", title: "Alphabetical") {
                selectedSorting = .alphabetical
            }
        }
        .padding(.vertical, 4)
        .frame(width: 200)
        .focusable(false)
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
            .applyButtonStyle()
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

