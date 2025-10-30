//
//  ConcurrencyCoordinator.swift
//  Picflow
//
//  Global concurrency coordinator for upload operations
//  Manages a pool of available slots for both file uploads and chunk uploads
//

import Foundation

/// Configuration for upload concurrency
struct UploadConcurrencyConfig {
    /// Maximum number of concurrent small file uploads
    /// Small files (single-part) can upload simultaneously
    static let maxConcurrentSmallFiles = 4
    
    /// Maximum number of concurrent chunk uploads within a large file
    /// Only one large file (multipart) uploads at a time, but chunks within it upload concurrently
    static let maxConcurrentChunks = 5
}

/// Actor that coordinates concurrent upload operations
/// Manages both small file concurrency and multipart upload exclusivity
actor ConcurrencyCoordinator {
    private let maxConcurrent: Int
    private var activeOperations: Int = 0
    private var waitingTasks: [CheckedContinuation<Void, Never>] = []
    
    // Multipart upload coordination
    private var isMultipartUploadActive: Bool = false
    private var waitingForMultipart: [CheckedContinuation<Void, Never>] = []
    
    init(maxConcurrent: Int = UploadConcurrencyConfig.maxConcurrentChunks) {
        self.maxConcurrent = maxConcurrent
    }
    
    /// Acquire exclusive lock for multipart upload
    /// Ensures only one multipart upload runs at a time
    func acquireMultipartLock() async {
        // Wait if another multipart upload is active
        if isMultipartUploadActive {
            await withCheckedContinuation { continuation in
                waitingForMultipart.append(continuation)
            }
        }
        isMultipartUploadActive = true
    }
    
    /// Release the multipart lock, allowing the next multipart upload to proceed
    func releaseMultipartLock() {
        isMultipartUploadActive = false
        
        // Resume the next waiting multipart upload if any
        if !waitingForMultipart.isEmpty {
            let continuation = waitingForMultipart.removeFirst()
            continuation.resume()
        }
    }
    
    /// Check if a multipart upload is currently active
    func isMultipartActive() -> Bool {
        return isMultipartUploadActive
    }
    
    /// Acquire a slot for an operation
    /// If no slots available, suspends until one becomes available
    func acquireSlot() async {
        if activeOperations < maxConcurrent {
            activeOperations += 1
            return
        }
        
        // Wait for a slot to become available
        await withCheckedContinuation { continuation in
            waitingTasks.append(continuation)
        }
        
        activeOperations += 1
    }
    
    /// Release a slot, allowing waiting operations to proceed
    func releaseSlot() {
        activeOperations -= 1
        
        // Resume the next waiting task if any
        if !waitingTasks.isEmpty {
            let continuation = waitingTasks.removeFirst()
            continuation.resume()
        }
    }
}

