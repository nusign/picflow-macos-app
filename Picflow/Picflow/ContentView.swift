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
    @State private var isTestMode = false
    @State private var showingUploader = false
    
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
                    
                    // Test Mode Badge
                    if isTestMode {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Test Mode")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                        .padding(6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(6)
                    }
                    
                    // OAuth Login Button
                    Button {
                        authenticator.startLogin()
                        isTestMode = false
                    } label: {
                        HStack {
                            Image(systemName: "lock.shield")
                            Text("Log in with Clerk")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Development Testing Section
                    VStack(spacing: 8) {
                    Text("Development Testing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Use Test Token") {
                        authenticator.authenticate(token: Constants.hardcodedToken)
                        Endpoint.currentTenantId = Constants.tenantId
                        isTestMode = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                }
                .padding()
            } else {
                // Show gallery selection or uploader view based on state
                if uploader.selectedGallery == nil || !showingUploader {
                    // Gallery Selection View
                    GallerySelectionView(
                        uploader: uploader,
                        onGallerySelected: {
                            showingUploader = true
                        }
                    )
                    .environmentObject(authenticator)
                } else {
                    // Uploader View
                    UploaderView(
                        uploader: uploader,
                        authenticator: authenticator,
                        onBack: {
                            showingUploader = false
                        }
                    )
                }
            }
        }
        .padding()
        .padding(.top, 8) // Extra padding for traffic lights
        .frame(minWidth: 480, minHeight: 700)
        .background(Color.clear) // Transparent to show visual effect view
    }
}
