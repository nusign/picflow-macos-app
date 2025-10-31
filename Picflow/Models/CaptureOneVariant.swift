//
//  CaptureOneVariant.swift
//  Picflow
//
//  Created by Michel Luarasi on 17.10.2025.
//

import Foundation

/// Represents a selected variant (image) in Capture One
struct CaptureOneVariant: Identifiable {
    let id: String
    let name: String
    let rating: Int?
    let colorTag: Int?
    let filePath: String?
    let cropWidth: Int?
    let cropHeight: Int?
    
    // EXIF data
    let cameraMake: String?
    let cameraModel: String?
    let iso: String?
    let shutterSpeed: String?
    let aperture: String?
    let focalLength: String?
    let captureDate: Date?
}

/// Selection state from Capture One
struct CaptureOneSelection {
    let count: Int
    let variants: [CaptureOneVariant]
    let documentName: String?
    
    var isEmpty: Bool {
        count == 0
    }
    
    var hasSelection: Bool {
        count > 0
    }
    
    var singleVariant: CaptureOneVariant? {
        count == 1 ? variants.first : nil
    }
}

