//
//  StreamTabView.swift
//  Picflow
//
//  Stream tab content: folder selection interface for live monitoring
//  Note: Live folder status is shown separately in GalleryView's status area
//

import SwiftUI

struct StreamTabView: View {
    @ObservedObject var folderManager: FolderMonitoringManager
    
    var body: some View {
        // Folder selection interface
        LiveFolderView(folderManager: folderManager)
    }
}

