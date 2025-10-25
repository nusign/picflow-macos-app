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
            // Header
            HStack {
                Spacer()
                Text("Choose Gallery")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding()
            
            // Content
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
                        ForEach(galleries, id: \.id) { gallery in
                            Button {
                                uploader.selectGallery(gallery)
                                onGallerySelected()
                            } label: {
                                GalleryCardView(gallery: gallery)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
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
} 
