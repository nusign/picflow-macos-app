//
//  FolderMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  Uses macOS FSEventStream API for efficient folder monitoring with automatic
//  event coalescing and low CPU usage.
//

import Foundation
import Sentry

enum FileEvent {
    case added
    case removed
    case modified
}

class FolderMonitor {
    private var eventStream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "FolderMonitor", qos: .utility)
    private var knownFiles = Set<String>()
    private let url: URL
    let callback: (URL, FileEvent) -> Void
    
    init(folderURL: URL, callback: @escaping (URL, FileEvent) -> Void) {
        self.url = folderURL
        self.callback = callback
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        // Capture initial state without triggering callbacks
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            knownFiles = Set(contents.filter { !isDirectory($0) }.map { $0.lastPathComponent })
            
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
        
        // Create FSEventStream context
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        
        let pathsToWatch = [url.path] as CFArray
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagUseCFTypes |
            kFSEventStreamCreateFlagFileEvents |
            kFSEventStreamCreateFlagNoDefer
        )
        
        // Create event stream with proper coalescing (1 second latency)
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            eventStreamCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // 1 second latency for event coalescing - reduces CPU usage
            flags
        )
        
        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            print("✅ FSEventStream monitoring started for: \(url.path)")
        } else {
            print("❌ Failed to create FSEventStream")
        }
    }
    
    func stopMonitoring() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
            print("🛑 FSEventStream monitoring stopped")
        }
    }
    
    fileprivate func handleEvents(eventPaths: [String], eventFlags: [FSEventStreamEventFlags]) {
        // Only scan if there were actual file changes (not just metadata)
        let relevantFlags: FSEventStreamEventFlags = UInt32(
            kFSEventStreamEventFlagItemCreated |
            kFSEventStreamEventFlagItemRemoved |
            kFSEventStreamEventFlagItemRenamed
        )
        
        let hasRelevantChanges = eventFlags.contains { flags in
            flags & relevantFlags != 0
        }
        
        guard hasRelevantChanges else {
            return
        }
        
        scanFolder()
    }
    
    private func scanFolder() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            let currentFiles = Set(
                contents.filter { !isDirectory($0) }.map { $0.lastPathComponent }
            )
            
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
    
    private func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }
}

// MARK: - FSEventStream Callback

private func eventStreamCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    
    let monitor = Unmanaged<FolderMonitor>.fromOpaque(info).takeUnretainedValue()
    let paths = unsafeBitCast(eventPaths, to: NSArray.self) as! [String]
    let flags = Array(UnsafeBufferPointer(start: eventFlags, count: numEvents))
    
    monitor.handleEvents(eventPaths: paths, eventFlags: flags)
}
