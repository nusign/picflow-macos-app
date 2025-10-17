//
//  ContentView.swift
//  Picflow
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
            if !authenticator.isAuthenticated {
                VStack(spacing: 16) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Welcome to Picflow")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Please log in to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Button {
                        authenticator.startLogin()
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Log in to Picflow")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Capture One Integration PoC (visible before auth for testing)
                    CaptureOneStatusView()
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    if let selectedGallery = uploader.selectedGallery {
                        VStack(spacing: 8) {
                            Text("Selected Gallery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(selectedGallery.displayName)
                                .font(.headline)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Button("Select Gallery") {
                        showingGallerySelection = true
                    }
                    .buttonStyle(.borderedProminent)
                    .sheet(isPresented: $showingGallerySelection) {
                        GallerySelectionView(uploader: uploader)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Capture One Integration PoC
                    CaptureOneStatusView()
                }
            }
        }
        .padding()
        .padding(.top, 8) // Extra padding for traffic lights
        .frame(minWidth: 480, minHeight: 700)
        .background(Color.clear) // Transparent to show visual effect view
    }
}
