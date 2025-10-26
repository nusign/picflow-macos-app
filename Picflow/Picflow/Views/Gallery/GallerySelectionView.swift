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
    @Environment(\.showDebugBorders) var showDebugBorders
    let onGallerySelected: () -> Void
    @State private var galleries: [GalleryDetails] = []
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                // Workspace Indicator
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("Current Workspace")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Title
                HStack {
                    Spacer()
                    Text("Choose Gallery")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .border(showDebugBorders ? Color.orange : Color.clear, width: 1) // DEBUG: Title
                    Spacer()
                }
            }
            .padding()
            .border(showDebugBorders ? Color.yellow : Color.clear, width: 2) // DEBUG: Header HStack
            
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
                                    .border(showDebugBorders ? Color.cyan : Color.clear, width: 1) // DEBUG: Gallery Card
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding()
                    .border(showDebugBorders ? Color.purple : Color.clear, width: 2) // DEBUG: LazyVStack
                    .frame(maxWidth: .infinity) // Center the container
                }
                .scrollIndicators(.automatic) // Show scrollbar when scrolling
                .border(showDebugBorders ? Color.blue : Color.clear, width: 2) // DEBUG: ScrollView
            }
        }
        .border(showDebugBorders ? Color.red : Color.clear, width: 3) // DEBUG: Outer VStack
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
