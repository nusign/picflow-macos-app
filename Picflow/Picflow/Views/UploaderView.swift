//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onBack: () -> Void
    @State private var isDragging = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ZStack(alignment: .topTrailing) {
                // Main Content
                VStack(spacing: 16) {
                    // Dropzone
                    DropzoneView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Capture One Integration
                    CaptureOneStatusView()
                }
                .padding(.top, 48) // Space for back button and avatar
                
                // User Profile Avatar (Fixed Top Right)
                if case .authorized(_, let profile) = authenticator.state {
                    UserProfileView(profile: profile, authenticator: authenticator)
                        .padding(.top, 8)
                        .padding(.trailing, 16)
                }
            }
            
            // Back Button (Fixed Top Left)
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Galleries")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            .padding(.leading, 16)
        }
    }
    
    // MARK: - File Handling
    
    private func handleFilesSelected(_ urls: [URL]) {
        print("📁 Files selected: \(urls.count)")
        for url in urls {
            print("  - \(url.lastPathComponent)")
            // TODO: Upload file
            Task {
                do {
                    try await uploader.upload(fileURL: url)
                    print("✅ Uploaded: \(url.lastPathComponent)")
                } catch {
                    print("❌ Upload failed: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Dropzone View

struct DropzoneView: View {
    @Binding var isDragging: Bool
    let onFilesSelected: ([URL]) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Upload Icon (96px placeholder)
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.accentColor)
            }
            
            // Title
            Text("Upload")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.primary)
            
            // Description
            Text("Drag and drop or choose files to upload to Picflow.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Choose Files Button
            Button("Choose Files") {
                selectFiles()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                )
                .foregroundColor(Color.black.opacity(isDragging ? 0.5 : 0.2))
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
        for provider in providers {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        onFilesSelected([url])
                    }
                }
            }
        }
    }
}

