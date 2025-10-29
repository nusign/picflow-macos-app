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
    
    var body: some View {
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)            
            // Development Login Button (Only in DEBUG builds)
            #if DEBUG
            VStack(spacing: 0) {                
                Button {
                    // Switch to development environment and login
                    environmentManager.current = .development
                    authenticator.startLogin()
                } label: {
                    HStack {
                        Text("Log in to Dev")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.orange)
            }
            #endif
        }
        .frame(maxWidth: 220)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

