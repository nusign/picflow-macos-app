//
//  GallerySelectionView.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//


import SwiftUI

struct GallerySelectionView: View {
    @ObservedObject var uploader: Uploader
    @State private var galleries: [GalleryDetails] = []
    @State private var isLoading = false
    @State private var error: Error?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading galleries...")
            } else if let error = error {
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
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(galleries, id: \.id) { gallery in
                            Button {
                                uploader.selectGallery(gallery)
                                dismiss()
                            } label: {
                                SelectedGalleryView(gallery: gallery)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 400, height: 600)
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
                httpMethod: .get
            ).response()
            
            galleries = response.data
        } catch {
            self.error = error
        }
        
        isLoading = false
    }
} 
