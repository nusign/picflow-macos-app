//
//  LoginView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authenticator: Authenticator
    @StateObject private var environmentManager = EnvironmentManager.shared
    @State private var isViewReady = false
    
    // Show dev button in DEBUG builds OR when developer mode is enabled
    private var showDevButton: Bool {
        #if DEBUG
        return true
        #else
        return DeveloperModeManager.shared.isEnabled
        #endif
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 8) {
                Image("Picflow-Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                
                VStack(spacing: 8) {
                    Text("Log in to Picflow")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        
                    Text("Click the button below to log in using your browser.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .padding(.bottom, 8)

                // OAuth Login Button (Production)
                Button {
                    // Ensure we're using production environment
                    environmentManager.current = .production
                    authenticator.startLogin()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .applyButtonStyle()
                .controlSize(.large)
                
                // Development Login Button (shown in DEBUG OR when developer mode enabled)
                if showDevButton {
                    Button {
                        // Switch to development environment and login
                        environmentManager.current = .development
                        authenticator.startLogin()
                    } label: {
                        HStack {
                            Text("Development")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .applySecondaryButtonStyle()
                    .controlSize(.large)
                    .tint(.orange)
                }
            }
            .frame(maxWidth: 220)
            .padding()
            
            Spacer()
        }
        .opacity(authenticator.isCheckingSession ? 0 : 1)
        .animation(isViewReady ? .easeIn(duration: 0.3) : nil, value: authenticator.isCheckingSession)
        .onAppear {
            // Allow layout to stabilize before enabling animations
            // This prevents layout recursion warnings during initial window setup
            DispatchQueue.main.async {
                isViewReady = true
            }
        }
    }
}

