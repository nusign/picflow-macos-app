//
//  Authenticator.swift
//  Picflow Live
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Profile
struct Profile: Codable {
    let firstName, lastName: String
    let email: String
}

// MARK: - Authentication Request
private struct AuthenticationRequest: Decodable {
    let token: String
}

// MARK: - GetProfile Response
private struct GetProfileResponse: Decodable {
    let user: Profile
}

// MARK: - Tenant
struct TenantResponse: Codable {
    let tenant: Tenant
}

struct Tenant: Codable {
    let id: String
    let name: String
    let path: String
    let logoUrl: String?
    let logoPosition: String?
    let contacts: Contacts?
    let socials: Socials?
    let createdAt: Date
    let updatedAt: Date
    let deletedAt: Date?
    
    struct Contacts: Codable {
        let site: String?
        let email: String?
    }
    
    struct Socials: Codable {
        let facebook: String?
        let instagram: String?
        let twitter: String?
        let linkedIn: String?
    }
}

// MARK: - Authenticator
@MainActor
class Authenticator: ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var tenant: TenantResponse.Tenant?
    private var token: String?
    
    enum State {
        case unauthorized
        case authenticating
        case authorized(token: String, profile: Profile)
    }
    
    @Published var state: State = .unauthorized
    
    func authenticate(token: String) {
        self.token = token
        Endpoint.token = token
        state = .authenticating
        
        Task {
            do {
                let response: GetProfileResponse = try await Endpoint(
                    path: "/v1/profile",
                    httpMethod: .get
                ).response()
                
                await MainActor.run {
                    state = .authorized(token: token, profile: response.user)
                    isAuthenticated = true
                }
            } catch {
                print("Authentication failed:", error)
                await MainActor.run {
                    state = .unauthorized
                    isAuthenticated = false
                }
            }
        }
    }
    
    func loadTenantDetails() async throws {
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        print("Making request to /v1/profile/current_tenant")
        let response: TenantResponse = try await Endpoint(
            path: "/v1/profile/current_tenant",
            httpMethod: .get
        ).response()
        
        await MainActor.run {
            self.tenant = response.tenant
        }
        
        print("Tenant details loaded:", response)
    }
    
    func logout() {
        state = .unauthorized
        isAuthenticated = false
        token = nil
        tenant = nil
        Endpoint.token = nil
    }
}

// MARK: - Authentication Error
enum AuthenticationError: Error {
    case notAuthenticated
    case invalidResponse
    case invalidToken
}
