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
            } else {
                // Authenticated App
                AppView(
                    uploader: uploader,
                    authenticator: authenticator
                )
            }
        }
        .frame(minWidth: 480, idealWidth: 480, maxWidth: .infinity, 
               minHeight: 400, idealHeight: 400, maxHeight: .infinity) // Fill window with minimum constraints
        .ignoresSafeArea() // Extend content into title bar area
        // Only animate the authentication state transition, not initial render
        .animation(.easeInOut(duration: 0.3), value: authenticator.isAuthenticated)
        .focusable(false) // Globally disable focus for entire content view hierarchy
    }
}