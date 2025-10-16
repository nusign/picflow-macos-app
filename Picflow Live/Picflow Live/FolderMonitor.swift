//
//  FolderMonitor.swift
//  Picflow Live
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation

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
        if let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
            knownFiles = Set(contents.map { $0.lastPathComponent })
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
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return
        }
        
        let currentFiles = Set(contents.map { $0.lastPathComponent })
        
        // Detect new files
        let addedFiles = currentFiles.subtracting(knownFiles)
        for file in addedFiles {
            callback(url.appendingPathComponent(file), .added)
        }
        
        // Detect removed files
        let removedFiles = knownFiles.subtracting(currentFiles)
        for file in removedFiles {
            callback(url.appendingPathComponent(file), .removed)
        }
        
        knownFiles = currentFiles
    }
}
