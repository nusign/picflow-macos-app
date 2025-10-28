//
//  KeychainTokenStore.swift
//  Picflow
//
//  Created by Michel Luarasi on 28.01.2025.
//

import Foundation
import Security

/// Secure storage for authentication tokens using macOS Keychain
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

