//
//  Environment.swift
//  Picflow
//
//  Manages environment configuration (DEV/PROD)
//

import Foundation

enum AppEnvironment: String, CaseIterable {
    case development = "Development"
    case production = "Production"
    
    var apiBaseURL: String {
        switch self {
        case .development:
            return "https://dev.picflow.com/api"
        case .production:
            return "https://picflow.com/api"
        }
    }
    
    var clerkDomain: String {
        switch self {
        case .development:
            return "relaxing-satyr-55.clerk.accounts.dev"
        case .production:
            return "clerk.picflow.com"
        }
    }
    
    var clerkClientId: String {
        switch self {
        case .development:
            return "kD3J6sN4GZliThzh"
        case .production:
            return "r3Zcs7yzt0s7iLtA"
        }
    }
    
    var redirectURI: String {
        // Same for both environments
        return "picflow-macos://auth/callback"
    }
    
    // Customer.io CDP configuration (HTTP API Source)
    var customerIOCdpApiKey: String {
        switch self {
        case .development:
            return "de4da9a43b8f30a56d86"  // Development HTTP API source
        case .production:
            return "05498e8c1c5a1702938c"  // Production HTTP API source
        }
    }
    
    var customerIOCdpBaseURL: String {
        // Custom domain (CNAME to Customer.io EU region)
        return "https://cdp.picflow.com/v1"
    }
    
    var customerIOSiteId: String {
        switch self {
        case .development:
            return "d890455b0fa2c4c2badb"
        case .production:
            return "19dda8b5fd362405c507"
        }
    }
}

/// Manages the current environment configuration
class EnvironmentManager: ObservableObject {
    static let shared = EnvironmentManager()
    
    private let storageKey = "com.picflow.macos.environment"
    
    @Published var current: AppEnvironment {
        didSet {
            UserDefaults.standard.set(current.rawValue, forKey: storageKey)
            Task { @MainActor in
                print("🌍 Environment switched to: \(current.rawValue)")
                print("   API: \(current.apiBaseURL)")
                print("   Clerk: \(current.clerkDomain)")
            }
        }
    }
    
    private init() {
        // Load from UserDefaults, default to Production
        if let saved = UserDefaults.standard.string(forKey: storageKey),
           let environment = AppEnvironment(rawValue: saved) {
            self.current = environment
        } else {
            self.current = .production
        }
        
        print("🌍 Environment initialized: \(current.rawValue)")
    }
}

