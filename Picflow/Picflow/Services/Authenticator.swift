//
//  Authenticator.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import Combine
import SwiftUI
import AuthenticationServices
import Security
import CryptoKit

// MARK: - Profile
struct Profile: Codable {
    let firstName: String
    let lastName: String
    let email: String
    let avatarUrl: String?
    
    var fullName: String {
        "\(firstName) \(lastName)"
    }
    
    var initials: String {
        let firstInitial = firstName.prefix(1).uppercased()
        let lastInitial = lastName.prefix(1).uppercased()
        return "\(firstInitial)\(lastInitial)"
    }
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
    let darkLogoUrl: String?
    let faviconUrl: String?
    let logoPosition: String?
    let contacts: Contacts?
    let socials: Socials?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
    
    struct Contacts: Codable {
        let site: String?
        let email: String?
        let phone: String?
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
class Authenticator: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var tenant: Tenant?
    @Published private(set) var availableTenants: [Tenant] = []
    private var token: String?
    
    enum State {
        case unauthorized
        case authenticating
        case authorized(token: String, profile: Profile)
        
        var authorizedProfile: Profile? {
            if case .authorized(_, let profile) = self {
                return profile
            }
            return nil
        }
    }
    
    @Published var state: State = .unauthorized
    
    // MARK: - OAuth (Clerk)
    private var authSession: ASWebAuthenticationSession?
    private var codeVerifier: String?
    private var codeChallenge: String?
    private let keychain = KeychainTokenStore(service: "com.picflow.macos.tokens")
    
    private var clerkDomain: String { 
        EnvironmentManager.shared.current.clerkDomain
    }
    private var clientId: String {
        EnvironmentManager.shared.current.clerkClientId
    }
    private var redirectURI: String { 
        EnvironmentManager.shared.current.redirectURI
    }
    
    struct OAuthTokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let token_type: String
        let expires_in: Int?
        let id_token: String?  // JWT token for backend authentication
    }
    
    func startLogin() {
        state = .authenticating
        
        // Build the OAuth authorization URL using Clerk's endpoint
        var components = URLComponents()
        components.scheme = "https"
        components.host = clerkDomain
        components.path = "/oauth/authorize"
        
        let verifier = PKCE.generateCodeVerifier()
        codeVerifier = verifier
        codeChallenge = PKCE.codeChallenge(for: verifier)
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: "openid profile email"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let url = components.url else {
            print("❌ Failed to build authorize URL")
            state = .unauthorized
            return
        }
        
        print("🔗 Opening authorization URL:", url.absoluteString)
        
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: "picflow-macos") { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Auth cancelled/failed:", error)
                print("❌ Error code:", (error as NSError).code)
                print("❌ Error domain:", (error as NSError).domain)
                Task { @MainActor in
                    self.state = .unauthorized
                    self.isAuthenticated = false
                }
                return
            }
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
                Task { @MainActor in
                    self.state = .unauthorized
                    self.isAuthenticated = false
                }
                return
            }
            Task { @MainActor in
                await self.handleRedirect(url: callbackURL)
            }
        }
        
        guard let session = authSession else {
            print("❌ Failed to create ASWebAuthenticationSession")
            state = .unauthorized
            return
        }
        
        session.presentationContextProvider = self
        session.prefersEphemeralWebBrowserSession = false
        
        print("🚀 Starting authentication session...")
        let started = session.start()
        
        if started {
            print("✅ Authentication session started successfully")
            // Activate the app to bring auth window to front
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NSApp.activate(ignoringOtherApps: true)
            }
        } else {
            print("❌ Failed to start authentication session")
            state = .unauthorized
        }
    }
    
    // MARK: - ASWebAuthenticationPresentationContextProviding
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Try to get the key window first, fallback to any visible window
        if let keyWindow = NSApplication.shared.keyWindow {
            print("📱 Using key window for auth presentation")
            return keyWindow
        }
        
        if let firstWindow = NSApplication.shared.windows.first(where: { $0.isVisible }) {
            print("📱 Using first visible window for auth presentation")
            return firstWindow
        }
        
        print("⚠️ No visible window found, creating new presentation anchor")
        return ASPresentationAnchor()
    }
    
    // Handle JWT token callback from web page
    func handleTokenCallback(url: URL) async {
        print("🔗 Received callback URL:", url.absoluteString)
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let tokenItem = components.queryItems?.first(where: { $0.name == "token" }),
              let token = tokenItem.value else {
            print("❌ No token found in callback URL")
            state = .unauthorized
            isAuthenticated = false
            return
        }
        
        print("✅ Received token, authenticating...")
        
        // Save token to keychain
        keychain.save(accessToken: token, refreshToken: nil)
        Endpoint.token = token
        self.token = token
        
        // Fetch profile to verify token
        do {
            let profile: GetProfileResponse = try await Endpoint(
                path: "/v1/profile",
                httpMethod: .get
            ).response()
            
            state = .authorized(token: token, profile: profile.user)
            isAuthenticated = true
            print("✅ Authentication successful!")
        } catch {
            print("❌ Failed to fetch profile:", error)
            state = .unauthorized
            isAuthenticated = false
        }
    }
    
    func handleRedirect(url: URL) async {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = comps.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value,
              let verifier = codeVerifier else {
            print("Invalid redirect URL or missing verifier")
            state = .unauthorized
            isAuthenticated = false
            return
        }
        do {
            let jwtToken = try await exchangeCodeForToken(code: code, verifier: verifier)
            keychain.save(accessToken: jwtToken, refreshToken: nil)
            Endpoint.token = jwtToken
            self.token = jwtToken
            
            // Don't set tenant yet - user will select it from workspace switcher
            print("✅ JWT token obtained, waiting for workspace selection...")
            
            print("🔄 Fetching user profile with JWT...")
            let profile: GetProfileResponse = try await Endpoint(
                path: "/v1/profile",
                httpMethod: .get
            ).response()
            state = .authorized(token: jwtToken, profile: profile.user)
            isAuthenticated = true
            print("✅ OAuth login complete!")
        } catch {
            print("❌ Token exchange failed:", error)
            state = .unauthorized
            isAuthenticated = false
        }
    }
    
    private func exchangeCodeForToken(code: String, verifier: String) async throws -> String {
        // Step 1: Exchange authorization code for OAuth access token
        var components = URLComponents()
        components.scheme = "https"
        components.host = clerkDomain
        components.path = "/oauth/token"
        guard let url = components.url else { throw EndpointError.urlConstructionFailed }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let bodyItems: [URLQueryItem] = [
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier)
        ]
        request.httpBody = bodyItems.percentEncoded()
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200...299 ~= http.statusCode else {
            print("❌ Token exchange failed with status:", (response as? HTTPURLResponse)?.statusCode ?? -1)
            throw EndpointError.invalidResponse
        }
        
        let tokenResponse = try JSONDecoder().decode(OAuthTokenResponse.self, from: data)
        print("✅ Got OAuth access token:", tokenResponse.access_token.prefix(20))
        
        // Check if we got an id_token (JWT) directly in the response
        if let idToken = tokenResponse.id_token, idToken.starts(with: "eyJ") {
            print("✅ Found JWT in id_token field:", idToken.prefix(50))
            return idToken
        }
        
        // If no id_token, the access_token itself might be the JWT
        if tokenResponse.access_token.starts(with: "eyJ") {
            print("✅ Access token is already a JWT:", tokenResponse.access_token.prefix(50))
            return tokenResponse.access_token
        }
        
        // Step 2: Try to exchange OAuth access token for session JWT via Clerk's userinfo endpoint
        print("🔄 OAuth token is not a JWT, trying to fetch session from Clerk...")
        
        // Try the OAuth userinfo endpoint first
        var userinfoComponents = URLComponents()
        userinfoComponents.scheme = "https"
        userinfoComponents.host = clerkDomain
        userinfoComponents.path = "/oauth/userinfo"
        
        if let userinfoUrl = userinfoComponents.url {
            var userinfoRequest = URLRequest(url: userinfoUrl)
            userinfoRequest.httpMethod = "GET"
            userinfoRequest.setValue("Bearer \(tokenResponse.access_token)", forHTTPHeaderField: "Authorization")
            
            do {
                let (_, userinfoResponse) = try await URLSession.shared.data(for: userinfoRequest)
                if let userinfoHttp = userinfoResponse as? HTTPURLResponse, 200...299 ~= userinfoHttp.statusCode {
                    print("✅ Got userinfo response")
                    // The userinfo endpoint doesn't give us a JWT, but confirms the token is valid
                    // For now, we'll have to use the OAuth access token directly
                    print("⚠️ Using OAuth access token directly (not ideal)")
                    return tokenResponse.access_token
                }
            } catch {
                print("⚠️ Userinfo endpoint failed:", error)
            }
        }
        
        print("❌ Could not obtain a JWT token from OAuth flow")
        print("💡 This might require backend configuration changes")
        throw EndpointError.invalidResponse
    }
    
    // Existing manual token path (kept for development/testing)
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
    
    // Test token authentication with hardcoded tenant (for development/testing)
    func authenticateWithTestToken(token: String, tenantId: String) {
        self.token = token
        Endpoint.token = token
        Endpoint.currentTenantId = tenantId
        state = .authenticating
        
        // Create a mock tenant for test mode
        let mockTenant = Tenant(
            id: tenantId,
            name: "Test Workspace",
            path: "test",
            logoUrl: nil,
            darkLogoUrl: nil,
            faviconUrl: nil,
            logoPosition: nil,
            contacts: nil,
            socials: nil,
            createdAt: Date(),
            updatedAt: Date(),
            deletedAt: nil
        )
        self.tenant = mockTenant
        
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
    
    // MARK: - Tenant Management
    
    func fetchAvailableTenants() async throws {
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        print("🔄 Fetching available tenants...")
        
        // Fetch user profile with tenants
        struct UserProfileResponse: Codable {
            let user: Profile
            let tenants: TenantsData
            
            struct TenantsData: Codable {
                let data: [Tenant]
            }
        }
        
        let response: UserProfileResponse = try await Endpoint(
            path: "/v1/profile/current_user",
            httpMethod: .get
        ).response()
        
        await MainActor.run {
            self.availableTenants = response.tenants.data
            print("✅ Found \(response.tenants.data.count) tenant(s):")
            for tenant in response.tenants.data {
                print("   - \(tenant.name) (ID: \(tenant.id))")
            }
        }
    }
    
    func selectTenant(_ tenant: Tenant) {
        self.tenant = tenant
        Endpoint.currentTenantId = tenant.id
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(tenant.id, forKey: "selectedTenantId")
        
        print("✅ Selected tenant: \(tenant.name) (ID: \(tenant.id))")
    }
    
    func restoreSavedTenant() {
        // Try to restore previously selected tenant
        guard let savedTenantId = UserDefaults.standard.string(forKey: "selectedTenantId"),
              let tenant = availableTenants.first(where: { $0.id == savedTenantId }) else {
            return
        }
        
        selectTenant(tenant)
        print("♻️ Restored saved tenant: \(tenant.name)")
    }
    
    func logout() {
        state = .unauthorized
        isAuthenticated = false
        token = nil
        tenant = nil
        availableTenants = []
        Endpoint.token = nil
        Endpoint.currentTenantId = nil
        keychain.clear()
        UserDefaults.standard.removeObject(forKey: "selectedTenantId")
    }
}

// MARK: - Authentication Error
enum AuthenticationError: Error {
    case notAuthenticated
    case invalidResponse
    case invalidToken
}

// MARK: - Helpers
private enum PKCE {
    static func generateCodeVerifier() -> String {
        let length = 64
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var result = ""
        for _ in 0..<length {
            if let c = characters.randomElement() { result.append(c) }
        }
        return result
    }
    
    static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        let sha256 = sha256(data)
        return base64URLEncode(sha256)
    }
    
    private static func sha256(_ data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }
    
    private static func base64URLEncode(_ data: Data) -> String {
        var s = data.base64EncodedString()
        s = s.replacingOccurrences(of: "+", with: "-")
             .replacingOccurrences(of: "/", with: "_")
             .replacingOccurrences(of: "=", with: "")
        return s
    }
}

private extension Array where Element == URLQueryItem {
    func percentEncoded() -> Data? {
        var components = URLComponents()
        components.queryItems = self
        return components.query?.data(using: .utf8)
    }
}

// MARK: - Keychain Token Store
final class KeychainTokenStore {
    private let service: String
    private let accountAccess = "accessToken"
    private let accountRefresh = "refreshToken"
    
    init(service: String) {
        self.service = service
    }
    
    func save(accessToken: String, refreshToken: String?) {
        saveGeneric(account: accountAccess, value: accessToken)
        if let refreshToken = refreshToken {
            saveGeneric(account: accountRefresh, value: refreshToken)
        }
    }
    
    func load() -> (access: String?, refresh: String?) {
        (loadGeneric(account: accountAccess), loadGeneric(account: accountRefresh))
    }
    
    func clear() {
        deleteGeneric(account: accountAccess)
        deleteGeneric(account: accountRefresh)
    }
    
    private func saveGeneric(account: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }
    
    private func loadGeneric(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func deleteGeneric(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
