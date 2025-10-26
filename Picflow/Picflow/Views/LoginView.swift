//
//  LoginView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

@available(macOS 26.0, *)
struct LoginView: View {
    @ObservedObject var authenticator: Authenticator
    
    var body: some View {
        ZStack {
            // Centered login form
            VStack(spacing: 16) {
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

                // OAuth Login Button
                Button {
                    authenticator.startLogin()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.top, 8)
            }
            .frame(maxWidth: 220)
            .padding()
            
            // Test token button - fixed to bottom right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        authenticator.authenticate(token: Constants.hardcodedToken)
                        Endpoint.currentTenantId = Constants.tenantId
                    } label: {
                        Text("Use Test Token")
                            .font(.system(size: 11))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

