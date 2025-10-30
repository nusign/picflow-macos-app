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
import Sentry

// MARK: - Private Response Wrappers

private struct GetProfileResponse: Decodable {
    let user: Profile
}

private struct OAuthTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let token_type: String
    let expires_in: Int?
    let id_token: String?  // JWT token for backend authentication
}

// MARK: - Authenticator
@MainActor
class Authenticator: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isCheckingSession = true
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
    private let keychain = KeychainTokenStore(service: "\(Constants.bundleIdentifier).tokens")
    
    private var clerkDomain: String { 
        EnvironmentManager.shared.current.clerkDomain
    }
    private var clientId: String {
        EnvironmentManager.shared.current.clerkClientId
    }
    private var redirectURI: String { 
        EnvironmentManager.shared.current.redirectURI
    }
    
    // MARK: - Session Restoration
    
    func restoreSession() async {
        print("🔄 Attempting to restore session from Keychain...")
        
        // Try to load stored tokens
        let (accessToken, _) = keychain.load()
        
        guard let accessToken = accessToken else {
            print("ℹ️ No stored tokens found")
            await MainActor.run {
                isCheckingSession = false
            }
            return
        }
        
        print("✅ Found stored token, validating...")
        
        // Set the token for API requests
        Endpoint.token = accessToken
        self.token = accessToken
        
        do {
            // Use shared method to complete authentication
            try await completeAuthentication(
                token: accessToken,
                method: "session_restore"
            )
            
            // Try to restore selected tenant from UserDefaults
            if let savedTenantId = UserDefaults.standard.string(forKey: "selectedTenantId") {
                print("🔄 Restoring selected tenant: \(savedTenantId)")
                Endpoint.currentTenantId = savedTenantId
                
                // Find and select the saved tenant from already-fetched list
                if let savedTenant = availableTenants.first(where: { $0.id == savedTenantId }) {
                    await MainActor.run {
                        self.tenant = savedTenant
                        print("✅ Tenant restored: \(savedTenant.name)")
                        
                        // Update analytics with tenant
                        if let profile = state.authorizedProfile {
                            AnalyticsManager.shared.identifyUser(profile: profile, tenant: savedTenant)
                        }
                    }
                } else {
                    print("⚠️ Saved tenant not found in available tenants")
                }
            }
            
            // Session restored successfully
            await MainActor.run {
                isCheckingSession = false
            }
            
        } catch {
            print("❌ Failed to restore session, token may be expired:", error)
            
            // Clear invalid tokens
            await MainActor.run {
                keychain.clear()
                Endpoint.token = nil
                self.token = nil
                state = .unauthorized
                isAuthenticated = false
                isCheckingSession = false
            }
            
            // Add breadcrumb
            ErrorReportingManager.shared.addBreadcrumb(
                "Session restoration failed",
                category: "auth",
                level: .warning,
                data: ["error": error.localizedDescription]
            )
            
            // Note: We don't show an alert for session restoration failure
            // because it's expected when tokens expire - user just needs to log in again
        }
    }
    
    // MARK: - Shared Authentication Completion
    
    /// Completes authentication by fetching profile and setting up state
    /// Used by both OAuth login and session restoration
    private func completeAuthentication(token: String, method: String) async throws {
        // Fetch profile to validate token
        let response: GetProfileResponse = try await Endpoint(
            path: "/v1/profile",
            httpMethod: .get
        ).response()
        
        // Set authenticated state
        await MainActor.run {
            state = .authorized(token: token, profile: response.user)
            isAuthenticated = true
            print("✅ Authentication complete for: \(response.user.email)")
            
            // Add breadcrumb
            ErrorReportingManager.shared.addBreadcrumb(
                "Authentication completed",
                category: "auth",
                level: .info,
                data: [
                    "user_email": response.user.email,
                    "method": method
                ]
            )
            
            // Identify user in analytics
            AnalyticsManager.shared.identifyUser(profile: response.user, tenant: nil)
        }
        
        // Fetch available tenants
        try await fetchAvailableTenants()
    }
    
    func startLogin() {
        state = .authenticating
        isCheckingSession = false  // Ensure LoginView stays visible during OAuth flow
        
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
            URLQueryItem(name: "scope", value: Constants.oauthScopes),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        
        guard let url = components.url else {
            print("❌ Failed to build authorize URL")
            state = .unauthorized
            return
        }
        
        print("🔗 Opening authorization URL:", url.absoluteString)
        
        authSession = ASWebAuthenticationSession(url: url, callbackURLScheme: Constants.appURLScheme) { [weak self] callbackURL, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Auth cancelled/failed:", error)
                print("❌ Error code:", (error as NSError).code)
                print("❌ Error domain:", (error as NSError).domain)
                
                // Capture to Sentry (unless user cancelled)
                let nsError = error as NSError
                if nsError.domain != ASWebAuthenticationSessionErrorDomain || nsError.code != ASWebAuthenticationSessionError.canceledLogin.rawValue {
                    reportAuthError(
                        error,
                        method: "oauth",
                        additionalContext: [
                            "error_code": nsError.code,
                            "error_domain": nsError.domain,
                            "auth_url": url.absoluteString
                        ]
                    )
                }
                
                Task { @MainActor in
                    self.state = .unauthorized
                    self.isAuthenticated = false
                }
                return
            }
            guard let callbackURL = callbackURL else {
                print("❌ No callback URL received")
                
                // Capture missing callback URL to Sentry
                let error = NSError(domain: "com.picflow.auth", code: 1001, userInfo: [
                    NSLocalizedDescriptionKey: "No callback URL received from OAuth flow"
                ])
                reportAuthError(
                    error,
                    method: "oauth",
                    additionalContext: ["auth_url": url.absoluteString]
                )
                
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
    
    // MARK: - OAuth Redirect Handler
    
    func handleRedirect(url: URL) async {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let codeItem = comps.queryItems?.first(where: { $0.name == "code" }),
              let code = codeItem.value,
              let verifier = codeVerifier else {
            print("Invalid redirect URL or missing verifier")
            
            // Capture to Sentry
            let error = NSError(domain: "com.picflow.auth", code: 1003, userInfo: [
                NSLocalizedDescriptionKey: "Invalid OAuth redirect URL or missing code verifier"
            ])
            reportAuthError(
                error,
                method: "oauth",
                additionalContext: [
                    "redirect_url": url.absoluteString,
                    "has_verifier": self.codeVerifier != nil
                ]
            )
            
            state = .unauthorized
            isAuthenticated = false
            return
        }
        do {
            let jwtToken = try await exchangeCodeForToken(code: code, verifier: verifier)
            
            // Save token to Keychain for persistence
            keychain.save(accessToken: jwtToken, refreshToken: nil)
            
            // Set token for API requests
            Endpoint.token = jwtToken
            self.token = jwtToken
            
            print("✅ JWT token obtained")
            
            // Use shared method to complete authentication
            try await completeAuthentication(token: jwtToken, method: "oauth")
            
            // Track login event (only for OAuth, not for session restore)
            await MainActor.run {
                AnalyticsManager.shared.trackLogin(method: "oauth")
                AnalyticsManager.shared.flush()
            }
            
            print("✅ OAuth login complete!")
        } catch {
            print("❌ Token exchange failed:", error)
            
            // Capture to Sentry
            reportAuthError(
                error,
                method: "oauth",
                additionalContext: [
                    "has_code": true,
                    "has_verifier": self.codeVerifier != nil
                ]
            )
            
            // Show error alert to user
            ErrorAlertManager.shared.showAuthenticationError(
                message: "Failed to complete authentication. Please try again.",
                error: error
            )
            
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
    
    
    // MARK: - Tenant Management
    
    func fetchAvailableTenants() async throws {
        guard isAuthenticated else {
            throw AuthenticationError.notAuthenticated
        }
        
        print("🔄 Fetching available tenants...")
        
        // Fetch tenants using the /v1/tenants endpoint
        struct TenantsResponse: Codable {
            let tenants: [Tenant]
            let sharedTenants: [Tenant]
        }
        
        let response: TenantsResponse = try await Endpoint(
            path: "/v1/tenants",
            httpMethod: .get
        ).response()
        
        await MainActor.run {
            // Combine owned and shared tenants
            var allTenants: [Tenant] = []
            
            // Add owned tenants
            allTenants.append(contentsOf: response.tenants)
            
            // Add shared tenants with isShared flag set to true
            let sharedTenantsWithFlag = response.sharedTenants.map { tenant -> Tenant in
                var mutableTenant = tenant
                mutableTenant.isShared = true
                return mutableTenant
            }
            allTenants.append(contentsOf: sharedTenantsWithFlag)
            
            self.availableTenants = allTenants
            
            print("✅ Found \(response.tenants.count) owned tenant(s) and \(response.sharedTenants.count) shared tenant(s):")
            for tenant in response.tenants {
                print("   - \(tenant.name) (ID: \(tenant.id))")
            }
            if !response.sharedTenants.isEmpty {
                print("   Shared:")
                for tenant in sharedTenantsWithFlag {
                    print("   - \(tenant.name) (ID: \(tenant.id)) [Guest]")
                }
            }
        }
    }
    
    func selectTenant(_ tenant: Tenant) {
        self.tenant = tenant
        Endpoint.currentTenantId = tenant.id
        
        // Save to UserDefaults for persistence
        UserDefaults.standard.set(tenant.id, forKey: "selectedTenantId")
        
        print("✅ Selected tenant: \(tenant.name) (ID: \(tenant.id))")
        
        // Track workspace selection and update user attributes
        AnalyticsManager.shared.trackWorkspaceSelected(tenant: tenant)
        
        // Update user identification with tenant information
        if let profile = state.authorizedProfile {
            AnalyticsManager.shared.identifyUser(profile: profile, tenant: tenant)
        }
    }
    
    func logout() {
        // Track logout event before clearing user data
        AnalyticsManager.shared.trackLogout()
        AnalyticsManager.shared.clearIdentification()
        
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
    
    // MARK: - Error Reporting Helpers
    
    /// Report authentication error with automatic context
    private func reportAuthError(
        _ error: Error,
        method: String,
        additionalContext: [String: Any] = [:]
    ) {
        var context = additionalContext
        
        // Automatically include auth state if available
        if case .authorized(_, let profile) = state {
            context["user_email"] = profile.email
        }
        
        context["auth_method"] = method
        
        ErrorReportingManager.shared.reportError(
            error,
            context: context,
            tags: ["operation": "auth", "auth_method": method]
        )
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