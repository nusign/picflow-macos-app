//
//  ContentView.swift
//  Picflow Live
//
//  Created by Michel Luarasi on 21.01.2025.
//

import SwiftUI
import UserNotifications
import AppKit

struct ContentView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    @State private var showingGallerySelection = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with logos
            HStack {
                if let tenantLogo = authenticator.tenant?.logoUrl {
                    AsyncImage(url: URL(string: tenantLogo)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(height: 40)
                    } placeholder: {
                        Color.gray.opacity(0.2)
                            .frame(width: 100, height: 40)
                    }
                }
                Spacer()
                Image("PicflowLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
            }
            .padding()
            
            if !authenticator.isAuthenticated {
                Text("Please log in to continue")
            } else {
                Button("Select Gallery") {
                    showingGallerySelection = true
                }
                .sheet(isPresented: $showingGallerySelection) {
                    GallerySelectionView(uploader: uploader)
                }
            }
        }
        .padding()
        .frame(minWidth: 480, minHeight: 480)
    }
}
