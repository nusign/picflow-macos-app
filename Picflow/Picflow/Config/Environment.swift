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
            return "https://dev.picflow.io"
        case .production:
            return "https://picflow.io"
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

