//
//  Uploader.swift
//  Picflow Live
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import SwiftUI

@MainActor
class Uploader: ObservableObject {
	@Published var selectedGallery: GalleryDetails?
	@Published var selectedSection: String?
	
	func selectGallery(_ gallery: GalleryDetails) {
		selectedGallery = gallery
		selectedSection = gallery.section
	}
}
