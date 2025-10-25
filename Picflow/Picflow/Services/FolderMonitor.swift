//
//  FolderMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
// TODO: Uncomment after adding Sentry SDK
// import Sentry

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
            
            // TODO: Uncomment after adding Sentry SDK
            /*
            SentrySDK.addBreadcrumb(crumb: Breadcrumb(
                level: .info,
                category: "folder_monitor"
            ).apply {
                $0.message = "Folder monitoring started"
                $0.data = [
                    "folder_path": url.path,
                    "initial_file_count": contents.count
                ]
            })
            */
        } catch {
            print("⚠️ Failed to read initial folder contents:", error)
            
            // TODO: Uncomment after adding Sentry SDK
            /*
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: [
                    "folder_path": url.path
                ], key: "folder_monitor")
                scope.setTag(value: "folder_monitor", key: "component")
            }
            */
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
                
                // TODO: Uncomment after adding Sentry SDK
                /*
                SentrySDK.addBreadcrumb(crumb: Breadcrumb(
                    level: .info,
                    category: "folder_monitor"
                ).apply {
                    $0.message = "File added to monitored folder"
                    $0.data = ["file_name": file]
                })
                */
            }
            
            // Detect removed files
            let removedFiles = knownFiles.subtracting(currentFiles)
            for file in removedFiles {
                callback(url.appendingPathComponent(file), .removed)
            }
            
            knownFiles = currentFiles
        } catch {
            print("⚠️ Failed to scan folder:", error)
            
            // TODO: Uncomment after adding Sentry SDK
            /*
            SentrySDK.capture(error: error) { scope in
                scope.setContext(value: [
                    "folder_path": url.path
                ], key: "folder_monitor")
                scope.setLevel(.warning)
            }
            */
        }
    }
}
