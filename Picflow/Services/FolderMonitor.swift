//
//  FolderMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  Simple FSEventStream-based folder monitoring that processes individual
//  file events directly without expensive directory scans.
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
        ErrorReportingManager.shared.addBreadcrumb(
            "Folder monitoring started",
            category: "folder_monitor",
            level: .info,
            data: ["folder_path": url.path]
        )
        
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
        
        // 2-second latency for better event coalescing
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            eventStreamCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0, // 2 seconds - coalesce events aggressively
            flags
        )
        
        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            print("✅ FSEventStream started: \(url.path)")
        }
    }
    
    func stopMonitoring() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }
    
    fileprivate func handleEvents(eventPaths: [String], eventFlags: [FSEventStreamEventFlags]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("📊 FSEvent callback: \(eventPaths.count) events")
        
        // Process each file event individually - no directory scanning
        for (index, path) in eventPaths.enumerated() {
            let flags = eventFlags[index]
            let fileURL = URL(fileURLWithPath: path)
            
            // Log what events we're seeing
            let flagNames = describeFSEventFlags(flags)
            print("  Event \(index): \(fileURL.lastPathComponent) - \(flagNames)")
            
            // Skip if not in our monitored folder
            guard fileURL.deletingLastPathComponent().path == url.path else { 
                print("  ↳ Skipped: not in monitored folder")
                continue 
            }
            
            // Skip hidden files and directories
            let filename = fileURL.lastPathComponent
            guard !filename.hasPrefix(".") else { 
                print("  ↳ Skipped: hidden file")
                continue 
            }
            
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            guard !isDir.boolValue else { 
                print("  ↳ Skipped: directory")
                continue 
            }
            
            // Only handle file creation events
            if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 && exists {
                print("  ↳ ✅ Processing file creation")
                callback(fileURL, .added)
                
                ErrorReportingManager.shared.addBreadcrumb(
                    "File added",
                    category: "folder_monitor",
                    level: .info,
                    data: ["file_name": filename]
                )
            } else {
                print("  ↳ Skipped: not a creation event or doesn't exist")
            }
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📊 FSEvent processing took: \(String(format: "%.2f", elapsed))ms")
    }
    
    private func describeFSEventFlags(_ flags: FSEventStreamEventFlags) -> String {
        var parts: [String] = []
        if flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0 { parts.append("Created") }
        if flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0 { parts.append("Removed") }
        if flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0 { parts.append("Renamed") }
        if flags & UInt32(kFSEventStreamEventFlagItemModified) != 0 { parts.append("Modified") }
        if flags & UInt32(kFSEventStreamEventFlagItemInodeMetaMod) != 0 { parts.append("MetaMod") }
        return parts.isEmpty ? "Unknown(\(flags))" : parts.joined(separator: ", ")
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

