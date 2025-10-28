//
//  Profile.swift
//  Picflow
//
//  Created by Michel Luarasi on 28.01.2025.
//

import Foundation

struct Profile: Codable {
    let id: String
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

