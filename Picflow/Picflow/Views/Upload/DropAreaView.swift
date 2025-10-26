//
//  DropAreaView.swift
//  Picflow
//
//  Drag-and-drop upload zone with file selection
//

import SwiftUI
import AppKit

struct DropAreaView: View {
    @Binding var isDragging: Bool
    let onFilesSelected: ([URL]) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 0) {
                // Icon
                Image("Image-Stack-Upload")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                
                VStack(spacing: 8) {
                    // Title
                    Text("Upload")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    // Description
                    Text("Drag and drop or choose files to upload to Picflow.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: 180)
                .padding(.bottom, 16)
                

                // Choose Files Button
                Button("Choose Files") {
                    selectFiles()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 8])
                )
                .foregroundColor(Color.primary.opacity(isDragging ? 0.5 : 0.2))
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .rawImage]
        
        if panel.runModal() == .OK {
            onFilesSelected(panel.urls)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var collectedURLs: [URL] = []
        let lock = NSLock()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    lock.lock()
                    collectedURLs.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        // Wait for all files to be collected, then call handler once
        group.notify(queue: .main) {
            if !collectedURLs.isEmpty {
                onFilesSelected(collectedURLs)
            }
        }
    }
}
