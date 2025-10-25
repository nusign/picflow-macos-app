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
        Group {
            if !authenticator.isAuthenticated {
                // Login Screen
                LoginView(authenticator: authenticator)
                    .transition(.opacity)
            } else {
                // Authenticated App
                AppView(
                    uploader: uploader,
                    authenticator: authenticator
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authenticator.isAuthenticated)
        .ignoresSafeArea() // Extend content into title bar area
    }
}
