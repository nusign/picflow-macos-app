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

