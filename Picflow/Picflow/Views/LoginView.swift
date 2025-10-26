//
//  LoginView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authenticator: Authenticator
    
    var body: some View {
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
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            
            // Development Testing
            VStack(spacing: 8) {
                Button("Use Test Token") {
                    authenticator.authenticate(token: Constants.hardcodedToken)
                    Endpoint.currentTenantId = Constants.tenantId
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.orange.opacity(0.2))
                )
                .foregroundColor(.orange)
            }
        }
        .frame(maxWidth: 220)
        .padding()
        .frame(width: 440, height: 320)
    }
}