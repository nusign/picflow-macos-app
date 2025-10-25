//
//  LoginView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var authenticator: Authenticator
    @State private var isTestMode = false
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Welcome to Picflow")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Please log in to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
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
            Button {
                authenticator.startLogin()
                isTestMode = false
            } label: {
                HStack {
                    Image(systemName: "lock.shield")
                    Text("Log in with Clerk")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)
            
            Divider()
                .padding(.vertical, 8)
            
            // Development Testing Section
            VStack(spacing: 8) {
                Text("Development Testing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Use Test Token") {
                    authenticator.authenticate(token: Constants.hardcodedToken)
                    Endpoint.currentTenantId = Constants.tenantId
                    isTestMode = true
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            }
        }
        .padding()
    }
}

