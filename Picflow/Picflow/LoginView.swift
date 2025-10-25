//
//  LoginView.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var authenticator = Authenticator()
    @State private var token: String = ""
    @State private var showError = false
    @State private var isTestMode = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login to Picflow")
                .font(.title)
            
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
            Button("Login with Clerk") {
                authenticator.startLogin()
                isTestMode = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Divider()
                .frame(width: 300)
            
            Text("Development Testing")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Test Token Button
            Button("Use Test Token") {
                authenticator.authenticate(token: Constants.hardcodedToken)
                Endpoint.currentTenantId = Constants.tenantId
                isTestMode = true
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            // Manual Token Entry (for advanced testing)
            VStack(spacing: 8) {
                TextField("Or enter custom token", text: $token)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 300)
                    .font(.caption)
                
                Button("Login with Custom Token") {
                    authenticator.authenticate(token: token)
                    isTestMode = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(token.isEmpty)
            }
            
            if case .authorized(_, let profile) = authenticator.state {
                Text("Logged in as \(profile.firstName) \(profile.lastName)")
                    .foregroundColor(.green)
                    .font(.subheadline)
            }
        }
        .padding()
        .frame(width: 450, height: 400)
    }
}
