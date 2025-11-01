//
//  UploadTabView.swift
//  Picflow
//
//  Upload tab content: manual upload interface (drag & drop, file picker)
//  Note: Capture One status is shown separately in GalleryView's status area
//

import SwiftUI

struct UploadTabView: View {
    @Binding var isDragging: Bool
    let onFilesSelected: ([URL]) -> Void
    
    var body: some View {
        // Manual upload interface (drag & drop, file picker)
        DropAreaView(isDragging: $isDragging, onFilesSelected: onFilesSelected)
    }
}

