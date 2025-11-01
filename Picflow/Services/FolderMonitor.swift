//
//  FolderMonitor.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//
//  FSEventStream-based folder monitoring with file readiness checks.
//  Uses per-file events and maturity polling to ensure files are fully written
//  before processing (critical for exports from apps like Capture One).
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
    private let readinessQueue = DispatchQueue(label: "FolderMonitor.Readiness", qos: .utility)
    private let url: URL
    let callback: (URL, FileEvent) -> Void
    
    // Readiness check configuration
    private let readinessCheckInterval: TimeInterval = 0.5 // 500ms between checks
    private let readinessCheckMaxAttempts = 6 // Max 3 seconds of checking
    
    // FSEventStreamEventId persistence for catch-up on restart
    private var lastEventId: FSEventStreamEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
    private var lastEventIdKey: String {
        "FolderMonitor.LastEventId.\(url.path.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "unknown")"
    }
    
    init(folderURL: URL, callback: @escaping (URL, FileEvent) -> Void, startFromNow: Bool = false) {
        self.url = folderURL
        self.callback = callback
        
        // Restore last event ID for catch-up (only if not starting from now)
        if !startFromNow, let savedId = UserDefaults.standard.object(forKey: lastEventIdKey) as? UInt64 {
            lastEventId = FSEventStreamEventId(savedId)
            print("📌 Restored FSEventStreamEventId: \(savedId)")
        } else {
            // Start from now - only detect new files from this point forward
            lastEventId = FSEventStreamEventId(kFSEventStreamEventIdSinceNow)
            print("📌 Starting from now (eventId: SinceNow)")
        }
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
            kFSEventStreamCreateFlagFileEvents |      // Per-file notifications
            kFSEventStreamCreateFlagWatchRoot |       // Detect folder moves/replacements
            kFSEventStreamCreateFlagIgnoreSelf        // Ignore changes we make
        )
        
        // 0.5-second latency: balance between batching and responsiveness
        eventStream = FSEventStreamCreate(
            kCFAllocatorDefault,
            eventStreamCallback,
            &context,
            pathsToWatch,
            lastEventId,  // Resume from last known event or SinceNow
            0.5,          // 500ms latency for good batching with reasonable response time
            flags
        )
        
        if let stream = eventStream {
            FSEventStreamSetDispatchQueue(stream, queue)
            FSEventStreamStart(stream)
            print("✅ FSEventStream started: \(url.path) (from eventId: \(lastEventId))")
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
    
    fileprivate func handleEvents(eventPaths: [String], eventFlags: [FSEventStreamEventFlags], eventIds: [FSEventStreamEventId]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("📊 FSEvent callback: \(eventPaths.count) events")
        
        // Update last event ID for persistence
        if let lastId = eventIds.last {
            lastEventId = lastId
            UserDefaults.standard.set(lastId, forKey: lastEventIdKey)
        }
        
        // Process each file event individually - no directory scanning
        for (index, path) in eventPaths.enumerated() {
            let flags = eventFlags[index]
            let fileURL = URL(fileURLWithPath: path)
            
            // Log what events we're seeing
            let flagNames = describeFSEventFlags(flags)
            print("  Event \(index): \(fileURL.lastPathComponent) - \(flagNames)")
            
            // Skip if not in our monitored folder (exact match, no recursion)
            guard fileURL.deletingLastPathComponent().path == url.path else { 
                print("  ↳ Skipped: not in monitored folder")
                continue 
            }
            
            // Skip hidden files and well-known temp files
            let filename = fileURL.lastPathComponent
            guard !filename.hasPrefix(".") && 
                  !filename.hasPrefix("._") &&
                  !filename.hasSuffix(".tmp") &&
                  filename != ".DS_Store" else { 
                print("  ↳ Skipped: hidden/temp file")
                continue 
            }
            
            // Check if this is a file (using FSEvents flag)
            let isFile = flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0
            guard isFile else {
                print("  ↳ Skipped: not a file (directory or other)")
                continue
            }
            
            // Check for file creation or atomic rename into folder
            let isCreated = flags & UInt32(kFSEventStreamEventFlagItemCreated) != 0
            let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0
            
            // Verify file exists
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            guard exists && !isDir.boolValue else {
                print("  ↳ Skipped: doesn't exist or is directory")
                continue
            }
            
            // Handle new files (created or renamed/moved into folder)
            if isCreated || (isRenamed && exists) {
                print("  ↳ 🔍 File detected, checking readiness...")
                
                // Check file readiness asynchronously before processing
                checkFileReadiness(fileURL: fileURL, filename: filename)
            } else {
                print("  ↳ Skipped: not a creation/rename event")
            }
        }
        
        let elapsed = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        print("📊 FSEvent processing took: \(String(format: "%.2f", elapsed))ms")
    }
    
    /// Checks if a file is ready (fully written) before processing.
    /// Uses size stability polling: checks file size multiple times and waits for it to stabilize.
    private func checkFileReadiness(fileURL: URL, filename: String, attempt: Int = 0) {
        readinessQueue.asyncAfter(deadline: .now() + readinessCheckInterval) { [weak self] in
            guard let self = self else { return }
            
            // Get current file size
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                  let currentSize = attributes[.size] as? UInt64 else {
                print("  ↳ ❌ File disappeared or unreadable: \(filename)")
                return
            }
            
            // Try opening the file for reading to ensure it's accessible
            guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
                if attempt < self.readinessCheckMaxAttempts {
                    print("  ↳ ⏳ File not readable yet (attempt \(attempt + 1)/\(self.readinessCheckMaxAttempts)): \(filename)")
                    self.checkFileReadiness(fileURL: fileURL, filename: filename, attempt: attempt + 1)
                } else {
                    print("  ↳ ❌ File never became readable: \(filename)")
                }
                return
            }
            try? fileHandle.close()
            
            // On first attempt, just record the size and check again
            if attempt == 0 {
                print("  ↳ ⏳ Initial size: \(currentSize) bytes, checking stability...")
                self.checkFileReadiness(fileURL: fileURL, filename: filename, attempt: 1)
                return
            }
            
            // Get the size from the previous check
            let previousSizeKey = "FolderMonitor.FileSize.\(fileURL.path)"
            let previousSize = UserDefaults.standard.object(forKey: previousSizeKey) as? UInt64 ?? 0
            
            // Update stored size
            UserDefaults.standard.set(currentSize, forKey: previousSizeKey)
            
            // If size hasn't changed, file is stable and ready
            if currentSize == previousSize && currentSize > 0 {
                print("  ↳ ✅ File stable and ready: \(filename) (\(currentSize) bytes)")
                
                // Clean up temporary size storage
                UserDefaults.standard.removeObject(forKey: previousSizeKey)
                
                // Process the file
                self.callback(fileURL, .added)
                
                ErrorReportingManager.shared.addBreadcrumb(
                    "File added (ready after \(attempt) checks)",
                    category: "folder_monitor",
                    level: .info,
                    data: ["file_name": filename, "size": currentSize]
                )
            } else if attempt < self.readinessCheckMaxAttempts {
                print("  ↳ ⏳ Size changed (\(previousSize) → \(currentSize) bytes), checking again (attempt \(attempt + 1)/\(self.readinessCheckMaxAttempts))...")
                self.checkFileReadiness(fileURL: fileURL, filename: filename, attempt: attempt + 1)
            } else {
                print("  ↳ ⚠️ File still changing after max attempts, processing anyway: \(filename)")
                
                // Clean up temporary size storage
                UserDefaults.standard.removeObject(forKey: previousSizeKey)
                
                // Process the file anyway - it might be a very large file that takes longer to write
                self.callback(fileURL, .added)
                
                ErrorReportingManager.shared.addBreadcrumb(
                    "File added (forced after max checks)",
                    category: "folder_monitor",
                    level: .warning,
                    data: ["file_name": filename, "size": currentSize]
                )
            }
        }
    }
    
    private func describeFSEventFlags(_ flags: FSEventStreamEventFlags) -> String {
        var parts: [String] = []
        if flags & UInt32(kFSEventStreamEventFlagItemIsFile) != 0 { parts.append("File") }
        if flags & UInt32(kFSEventStreamEventFlagItemIsDir) != 0 { parts.append("Dir") }
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
    let ids = Array(UnsafeBufferPointer(start: eventIds, count: numEvents))
    
    monitor.handleEvents(eventPaths: paths, eventFlags: flags, eventIds: ids)
}



