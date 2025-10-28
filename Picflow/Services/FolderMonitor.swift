//
//  FolderMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import Sentry

enum FileEvent {
    case added
    case removed
    case modified
}

class FolderMonitor {
    private var fileDescriptor: Int32
    private var source: DispatchSourceFileSystemObject?
    private let queue = DispatchQueue(label: "FolderMonitor", attributes: .concurrent)
    private var knownFiles = Set<String>()
    private let url: URL
    let callback: (URL, FileEvent) -> Void
    
    init(folderURL: URL, callback: @escaping (URL, FileEvent) -> Void) {
        self.url = folderURL
        self.callback = callback
        self.fileDescriptor = open(folderURL.path, O_EVTONLY)
    }
    
    deinit {
        stopMonitoring()
        close(fileDescriptor)
    }
    
    func startMonitoring() {
        // Capture initial state without triggering callbacks
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            knownFiles = Set(contents.map { $0.lastPathComponent })
            
            ErrorReportingManager.shared.addBreadcrumb(
                "Folder monitoring started",
                category: "folder_monitor",
                level: .info,
                data: [
                    "folder_path": url.path,
                    "initial_file_count": contents.count
                ]
            )
        } catch {
            print("⚠️ Failed to read initial folder contents:", error)
            
            ErrorReportingManager.shared.reportError(
                error,
                context: ["folder_path": self.url.path],
                tags: ["operation": "folder_monitor"]
            )
        }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        
        source?.setEventHandler { [weak self] in
            self?.scanFolder()
        }
        
        source?.resume()
    }
    
    func stopMonitoring() {
        source?.cancel()
        source = nil
    }
    
    private func scanFolder() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            let currentFiles = Set(contents.map { $0.lastPathComponent })
            
            // Detect new files
            let addedFiles = currentFiles.subtracting(knownFiles)
            for file in addedFiles {
                callback(url.appendingPathComponent(file), .added)
                
                ErrorReportingManager.shared.addBreadcrumb(
                    "File added to monitored folder",
                    category: "folder_monitor",
                    level: .info,
                    data: ["file_name": file]
                )
            }
            
            // Detect removed files
            let removedFiles = knownFiles.subtracting(currentFiles)
            for file in removedFiles {
                callback(url.appendingPathComponent(file), .removed)
            }
            
            knownFiles = currentFiles
        } catch {
            print("⚠️ Failed to scan folder:", error)
            
            ErrorReportingManager.shared.reportError(
                error,
                context: ["folder_path": self.url.path],
                tags: ["operation": "folder_monitor"]
            )
        }
    }
}
