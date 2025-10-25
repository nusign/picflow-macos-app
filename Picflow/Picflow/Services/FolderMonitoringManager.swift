//
//  FolderMonitoringManager.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import UserNotifications

struct FileChange: Equatable {
    let fileName: String
    let action: String
    let timestamp: Date
    
    static func == (lhs: FileChange, rhs: FileChange) -> Bool {
        lhs.timestamp == rhs.timestamp && 
        lhs.fileName == rhs.fileName &&
        lhs.action == rhs.action
    }
}

class FolderMonitoringManager: ObservableObject {
    @Published private(set) var latestChange: FileChange?
    private var monitor: FolderMonitor?
    private let uploader: Uploader
    private var hideTask: Task<Void, Never>?
    
    init(uploader: Uploader) {
        self.uploader = uploader
    }
    
    func startMonitoring(_ url: URL) {
        stopMonitoring()
        print("Starting monitoring for folder: \(url.path)")
        
        monitor = FolderMonitor(folderURL: url) { [weak self] fileURL, eventType in
            guard let self = self else {
                print("Self is nil in folder monitor callback")
                return
            }
            
            print("File event detected: \(eventType) - \(fileURL.lastPathComponent)")
            guard fileURL.lastPathComponent != ".DS_Store" else { return }
            
            let action: String
            switch eventType {
            case .added:
                print("New file added: \(fileURL.path)")
                Task {
                    do {
                        print("Starting upload for: \(fileURL.path)")
                        try await self.uploader.upload(fileURL: fileURL)
                        print("Upload completed successfully")
                    } catch {
                        print("Upload failed with error: \(error)")
                    }
                }
                action = "added"
            case .removed:
                print("File removed: \(fileURL.path)")
                action = "removed"
            case .modified:
                print("File modified: \(fileURL.path)")
                action = "modified"
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else {
                    print("Self is nil in MainActor task")
                    return
                }
                
                print("Updating UI for file change: \(action)")
                self.hideTask?.cancel()
                
                self.latestChange = FileChange(
                    fileName: fileURL.lastPathComponent,
                    action: action,
                    timestamp: Date()
                )
                
                self.hideTask = Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    do {
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        if !Task.isCancelled {
                            self.latestChange = nil
                        }
                    } catch {
                        print("Hide task error: \(error)")
                    }
                }
            }
            
            self.showNotification(for: fileURL.lastPathComponent, action: action)
        }
        monitor?.startMonitoring()
    }
    
    func stopMonitoring() {
        monitor?.stopMonitoring()
        monitor = nil
        hideTask?.cancel()
        hideTask = nil
        latestChange = nil
    }
    
    private func showNotification(for filename: String, action: String) {
        let content = UNMutableNotificationContent()
        content.title = "File Changed"
        content.body = "\(filename) has been \(action)."
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
} 
