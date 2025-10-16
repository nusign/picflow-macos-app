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
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Login to Picflow")
                .font(.title)
            
            TextField("Enter your API token", text: $token)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 300)
            
            Button("Login") {
                authenticator.authenticate(token: token)
            }
            .disabled(token.isEmpty)
            
            if case .authorized(_, let profile) = authenticator.state {
                Text("Logged in as \(profile.firstName) \(profile.lastName)")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}
