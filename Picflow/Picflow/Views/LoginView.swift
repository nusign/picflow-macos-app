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
            
            Text("Welcome to Picflow")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Click the button below to log in using your browser.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
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
            
            // Development Testing Section
            VStack(spacing: 8) {
                Button("Use Test Token") {
                    authenticator.authenticate(token: Constants.hardcodedToken)
                    Endpoint.currentTenantId = Constants.tenantId
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: 180)
        .padding()
        .frame(width: 440, height: 320)
    }
}
