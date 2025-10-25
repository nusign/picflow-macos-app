//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onBack: () -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topTrailing) {
                // Main Content
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
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Capture One Integration PoC
                    CaptureOneStatusView()
                }
                .padding(.top, 48) // Space for back button and avatar
                
                // User Profile Avatar (Fixed Top Right)
                if case .authorized(_, let profile) = authenticator.state {
                    UserProfileView(profile: profile, authenticator: authenticator)
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            
            // Back Button (Fixed Top Left)
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Galleries")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.leading, 16)
        }
    }
}

