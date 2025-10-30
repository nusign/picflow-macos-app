//
//  MultiPartUploadConfig.swift
//  Picflow
//
//  Created by Michel Luarasi on 29.10.2025.
//

import Foundation

struct MultiPartUploadConfig {
    /// Possible chunk sizes supported by the backend
    /// These are the sizes the backend uses to determine part count
    static let possibleChunkSizes: [Int64] = [
        10 * 1024 * 1024,   // 10 MB
        100 * 1024 * 1024,  // 100 MB
        250 * 1024 * 1024   // 250 MB
    ]
    
    /// File size threshold for using multipart upload (configurable)
    /// Files larger than this will use multipart upload
    static let multipartThresholdMB: Int64 = 25
    static var multipartThreshold: Int64 {
        multipartThresholdMB * 1024 * 1024
    }
    
    /// Number of retry attempts for failed chunk uploads
    static let maxRetryAttempts = 3
    
    /// Delay between retry attempts (exponential backoff)
    static func retryDelay(for attempt: Int) -> TimeInterval {
        return pow(2.0, Double(attempt)) // 2s, 4s, 8s
    }
    
    /// Calculate chunk size based on file size and part count
    /// This reverse-engineers the backend's algorithm to determine which chunk size was used
    ///
    /// Backend algorithm: Math.floor(contentLength / chunkSize) + 1
    ///
    /// - Parameters:
    ///   - fileSize: Total size of the file in bytes
    ///   - partCount: Number of parts/URLs provided by backend
    /// - Returns: The chunk size in bytes that the backend used
    static func calculateChunkSize(fileSize: Int64, partCount: Int) -> Int64 {
        // Try each possible chunk size to find the one that matches the part count
        for chunkSize in possibleChunkSizes {
            // Backend uses: Math.floor(contentLength / size) + 1
            let calculatedPartCount = (fileSize / chunkSize) + 1
            
            if calculatedPartCount == Int64(partCount) {
                return chunkSize
            }
        }
        
        // Fallback to largest size if no exact match
        // This handles edge cases and potential future backend changes
        return possibleChunkSizes.last!
    }
    
    /// Determine if a file should use multipart upload based on size
    /// - Parameter fileSize: Size of the file in bytes
    /// - Returns: true if file should use multipart upload
    static func shouldUseMultipart(fileSize: Int64) -> Bool {
        return fileSize > multipartThreshold
    }
}

