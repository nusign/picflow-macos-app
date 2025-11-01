//
//  AnalyticsManager.swift
//  Picflow
//
//  Created by Michel Luarasi on 28.01.2025.
//

import Foundation

/// Manages analytics tracking via Customer.io CDP using direct HTTP API calls
/// Provider-agnostic interface for user tracking and event analytics
/// Uses HTTP API Source for immediate, reliable event delivery with retry logic
@MainActor
class AnalyticsManager: ObservableObject {
    static let shared = AnalyticsManager()
    
    private var isInitialized = false
    private var apiKey: String = ""
    private var baseURL: String = ""
    private var currentUserId: String?
    private var anonymousId: String = UUID().uuidString
    
    private init() {}
    
    // MARK: - User Agent
    
    /// Generate a custom user agent string for analytics requests
    private var userAgent: String {
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osVersionString = "\(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        
        // Format: Picflow/1.0.0 (build 123; macOS 14.0.0)
        return "Picflow/\(appVersion) (build \(buildNumber); macOS \(osVersionString))"
    }
    
    // MARK: - Initialization
    
    /// Initialize analytics HTTP API
    func initialize() {
        guard !isInitialized else {
            print("⚠️ Analytics already initialized")
            return
        }
        
        let environment = EnvironmentManager.shared.current
        self.apiKey = environment.customerIOCdpApiKey
        self.baseURL = environment.customerIOCdpBaseURL
        
        isInitialized = true
        
        print("✅ Analytics (Customer.io CDP) initialized for \(environment.rawValue) environment")
        print("   API Key: \(apiKey)")
        print("   Base URL: \(baseURL)")
        print("   Mode: Direct HTTP with retry logic")
    }
    
    // MARK: - User Identification
    
    /// Identify user when they log in
    /// Matches web app format: userId in traits, userType, and minimal required fields
    func identifyUser(profile: Profile, tenant: Tenant?) {
        guard isInitialized else {
            print("⚠️ Analytics not initialized, cannot identify user")
            return
        }
        
        // Match web app format: only include required traits
        let traits: [String: Any] = [
            "userType": "customer",
            "userId": profile.id,
            "first_name": profile.firstName,
            "last_name": profile.lastName,
            "email": profile.email
        ]
        
        // Use profile.id as userId (not email) to match web app
        sendIdentify(userId: profile.id, traits: traits)
        storeUserId(profile.id)
        
        print("✅ Analytics: User identified - \(profile.email) (ID: \(profile.id))")
    }
    
    /// Clear user identification when they log out
    func clearIdentification() {
        guard isInitialized else { return }
        
        currentUserId = nil
        print("✅ Analytics: User session ended")
    }
    
    // MARK: - Event Tracking
    
    /// Track user login event
    func trackLogin(method: String = "oauth") {
        trackEvent("user_logged_in", properties: [
            "method": method,
            "platform": "macos"
        ])
    }
    
    /// Track user logout event
    func trackLogout() {
        trackEvent("user_logged_out", properties: [
            "platform": "macos"
        ])
    }
    
    /// Track workspace/tenant selection
    func trackWorkspaceSelected(tenant: Tenant) {
        trackEvent("workspace_selected", properties: [
            "tenant_id": tenant.id,
            "tenant_name": tenant.name,
            "tenant_path": tenant.path
        ])
    }
    
    /// Track gallery selection
    func trackGallerySelected(gallery: GalleryDetails) {
        var properties: [String: Any] = [
            "gallery_id": gallery.id,
            "gallery_display_name": gallery.displayName
        ]
        
        if let name = gallery.name {
            properties["gallery_name"] = name
        }
        
        trackEvent("gallery_selected", properties: properties)
    }
    
    /// Track upload started
    func trackUploadStarted(fileCount: Int, galleryId: String) {
        trackEvent("upload_started", properties: [
            "file_count": fileCount,
            "gallery_id": galleryId
        ])
    }
    
    /// Track single file upload completed
    func trackFileUploaded(fileName: String, fileSize: Int, galleryId: String) {
        trackEvent("file_uploaded", properties: [
            "file_name": fileName,
            "file_size": fileSize,
            "gallery_id": galleryId
        ])
    }
    
    /// Track all uploads completed
    func trackUploadCompleted(fileCount: Int, totalSize: Int64, duration: TimeInterval, galleryId: String) {
        trackEvent("upload_completed", properties: [
            "file_count": fileCount,
            "total_size": totalSize,
            "duration_seconds": duration,
            "gallery_id": galleryId,
            "average_speed_mbps": (Double(totalSize) / duration) / 1_000_000
        ])
    }
    
    /// Track upload failed
    func trackUploadFailed(fileName: String?, error: String, galleryId: String?) {
        var properties: [String: Any] = [
            "error": error
        ]
        
        if let fileName = fileName {
            properties["file_name"] = fileName
        }
        
        if let galleryId = galleryId {
            properties["gallery_id"] = galleryId
        }
        
        trackEvent("upload_failed", properties: properties)
    }
    
    // MARK: - Private HTTP Methods
    
    private func sendIdentify(userId: String, traits: [String: Any]) {
        guard isInitialized else { return }
        
        // Customer.io CDP uses /v1/i endpoint for identify
        let endpoint = "\(baseURL)/i"
        
        // Customer.io CDP expects Segment-compatible format
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let messageId = "ajs-next-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        let payload: [String: Any] = [
            "type": "identify",
            "userId": userId,
            "traits": traits,
            "timestamp": timestamp,
            "integrations": [
                "Customer.io Data Pipelines": true
            ],
            "anonymousId": anonymousId,
            "context": [
                "connection": "macos",
                "library": [
                    "name": "analytics.swift",
                    "version": "custom"
                ],
                "userAgent": userAgent,
                "locale": Locale.current.identifier
            ],
            "messageId": messageId,
            "writeKey": apiKey,
            "sentAt": timestamp
        ]
        
        print("📤 Sending identify for user: \(userId)")
        sendRequest(to: endpoint, payload: payload, eventName: "identify")
    }
    
    private func trackEvent(_ eventName: String, properties: [String: Any]) {
        guard isInitialized else {
            print("⚠️ Analytics not initialized, cannot track event: \(eventName)")
            return
        }
        
        guard let userId = getCurrentUserId() else {
            print("⚠️ No user ID available, cannot track event: \(eventName)")
            print("   Current userId: \(currentUserId ?? "nil")")
            return
        }
        
        // Customer.io CDP uses /v1/t endpoint for track
        // Match web app format exactly
        let endpoint = "\(baseURL)/t"
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let messageId = "ajs-next-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        
        let payload: [String: Any] = [
            "timestamp": timestamp,
            "integrations": [
                "Customer.io Data Pipelines": true
            ],
            "userId": userId,
            "anonymousId": anonymousId,
            "event": eventName,  // Use "event" instead of "name"
            "type": "track",
            "properties": properties,
            "context": [
                "connection": "macos",
                "library": [
                    "name": "analytics.swift",
                    "version": "custom"
                ],
                "userAgent": userAgent,
                "locale": Locale.current.identifier
            ],
            "messageId": messageId,
            "writeKey": apiKey,  // Include writeKey in payload
            "sentAt": timestamp
        ]
        
        // Always log track events for debugging
        print("📤 Sending track event: \(eventName) for user: \(userId)")
        sendRequest(to: endpoint, payload: payload, eventName: eventName)
    }
    
    private func sendRequest(to endpoint: String, payload: [String: Any], eventName: String) {
        guard let url = URL(string: endpoint) else {
            print("❌ Invalid URL: \(endpoint)")
            return
        }
        
        // Serialize JSON payload once
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            
            // Always log payload for track events, DEBUG only for identify
            if eventName != "identify" {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🌐 Sending \(eventName) to: \(endpoint)")
                    print("   Payload: \(jsonString)")
                }
            } else {
                #if DEBUG
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("🌐 Sending \(eventName) to: \(endpoint)")
                    print("   Payload: \(jsonString)")
                }
                #endif
            }
        } catch {
            print("❌ Failed to serialize payload for \(eventName): \(error)")
            return
        }
        
        // Send with retry logic
        Task {
            await sendRequestWithRetry(
                url: url,
                jsonData: jsonData,
                eventName: eventName,
                maxAttempts: 3
            )
        }
    }
    
    private func sendRequestWithRetry(url: URL, jsonData: Data, eventName: String, maxAttempts: Int) async {
        var attempt = 0
        
        while attempt < maxAttempts {
            attempt += 1
            
            // Create request
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 30
            
            // Add Basic Auth header
            let credentials = "\(apiKey):".data(using: .utf8)!.base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            request.httpBody = jsonData
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("⚠️ \(eventName) - Attempt \(attempt)/\(maxAttempts) - Invalid response")
                    if attempt < maxAttempts {
                        await retryDelay(attempt: attempt)
                        continue
                    }
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    // Log response body for debugging track events
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    if eventName != "identify" {
                        print("✅ \(eventName) - HTTP 200 - Succeeded")
                        print("   Response: \(responseBody)")
                    } else if attempt > 1 {
                        print("✅ \(eventName) succeeded (attempt \(attempt))")
                    }
                    return // Success!
                } else if httpResponse.statusCode >= 500 {
                    // Server error - retry
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    print("⚠️ \(eventName) - Attempt \(attempt)/\(maxAttempts) - HTTP \(httpResponse.statusCode): \(responseBody)")
                    
                    if attempt < maxAttempts {
                        await retryDelay(attempt: attempt)
                        continue
                    } else {
                        print("❌ \(eventName) - Failed after \(maxAttempts) attempts")
                        return
                    }
                } else if httpResponse.statusCode >= 400 {
                    // Client error - don't retry
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    print("❌ \(eventName) - HTTP \(httpResponse.statusCode) (client error, not retrying): \(responseBody)")
                    return
                } else {
                    // Unexpected status code
                    let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
                    print("⚠️ \(eventName) - Attempt \(attempt)/\(maxAttempts) - HTTP \(httpResponse.statusCode): \(responseBody)")
                    
                    if attempt < maxAttempts {
                        await retryDelay(attempt: attempt)
                        continue
                    }
                    return
                }
                
            } catch {
                // Network error - retry
                print("⚠️ \(eventName) - Attempt \(attempt)/\(maxAttempts) - Network error: \(error.localizedDescription)")
                
                if attempt < maxAttempts {
                    await retryDelay(attempt: attempt)
                    continue
                } else {
                    print("❌ \(eventName) - Failed after \(maxAttempts) attempts: \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    private func retryDelay(attempt: Int) async {
        // Exponential backoff: 1s, 2s, 4s
        let delay = TimeInterval(pow(2.0, Double(attempt - 1)))
        print("   ⏳ Retrying in \(delay)s...")
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }
    
    // MARK: - Helper Methods
    
    private func storeUserId(_ userId: String) {
        currentUserId = userId
    }
    
    private func getCurrentUserId() -> String? {
        return currentUserId
    }
    
    // MARK: - Debug Methods
    
    /// Force flush events immediately (no-op for direct HTTP, kept for API compatibility)
    func flush() {
        print("🔄 Analytics: Flush called (direct HTTP sends immediately)")
    }
}

