//
//  Tenant.swift
//  Picflow
//
//  Created by Michel Luarasi on 28.01.2025.
//

import Foundation

struct Tenant: Codable {
    let id: String
    let name: String
    let path: String
    let faviconUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
    let storageSize: String?
    
    // This property is set by the app to distinguish owned vs shared tenants
    // Not part of the API response
    var isShared: Bool = false
    
    // Custom coding keys to handle the isShared property
    enum CodingKeys: String, CodingKey {
        case id, name, path, faviconUrl
        case createdAt, updatedAt, deletedAt
        case storageSize
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        path = try container.decode(String.self, forKey: .path)
        faviconUrl = try container.decodeIfPresent(String.self, forKey: .faviconUrl)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        storageSize = try container.decodeIfPresent(String.self, forKey: .storageSize)
        isShared = false  // Default value, will be set explicitly when parsing /v1/tenants response
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(path, forKey: .path)
        try container.encodeIfPresent(faviconUrl, forKey: .faviconUrl)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(storageSize, forKey: .storageSize)
    }
}

