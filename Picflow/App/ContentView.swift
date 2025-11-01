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
    
    var body: some View {
        NavigationStack {
            Group {
                if !authenticator.isAuthenticated {
                    // Login Screen
                    LoginView(authenticator: authenticator)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Authenticated App - fills available space, no ScrollView needed
                    AppView(
                        uploader: uploader,
                        authenticator: authenticator
                    )
                }
            }
            // Only animate the authentication state transition, not initial render
            .animation(.easeInOut(duration: 0.3), value: authenticator.isAuthenticated)
            .focusable(false) // Globally disable focus for entire content view hierarchy
            .navigationTitle("") // Use to avoid the default "Picflow" title
            .toolbarBackground(.automatic, for: .windowToolbar)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Spacer()
                }
            }
        }
    }
}

// MARK: - macOS 26 Feature Compatibility Helpers

extension View {
    /// Applies glass prominent button style on macOS 26+, falls back to borderedProminent on older versions
    @ViewBuilder
    func applyButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent)
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
    
    /// Applies glass button style on macOS 26+, falls back to bordered on older versions
    @ViewBuilder
    func applySecondaryButtonStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
    
    /// Applies navigation subtitle on macOS 26+, no-op on older versions
    @ViewBuilder
    func applyNavigationSubtitle(_ subtitle: String) -> some View {
        if #available(macOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self // No subtitle support on older macOS versions
        }
    }
    
    /// Applies glass effect to Menu on macOS 26+, falls back to borderedProminent on older versions
    @ViewBuilder
    func applyMenuGlassEffect() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect()
        } else {
            self.buttonStyle(.borderedProminent)
        }
    }
}