//
//  ChunkedFileReader.swift
//  Picflow
//
//  Created by Michel Luarasi on 29.10.2025.
//

import Foundation

/// Memory-efficient file reader that streams chunks from disk
/// instead of loading the entire file into memory
class ChunkedFileReader {
    private let fileHandle: FileHandle
    private let fileURL: URL
    let fileSize: Int64
    
    /// Initialize a chunked file reader
    /// - Parameter fileURL: URL of the file to read
    /// - Throws: UploadError if file doesn't exist or can't be read
    init(fileURL: URL) throws {
        self.fileURL = fileURL
        
        // Verify file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw UploadError.fileNotFound
        }
        
        // Get file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            self.fileSize = attributes[.size] as? Int64 ?? 0
        } catch {
            throw UploadError.fileReadError(error)
        }
        
		// Open file handle for reading
		do {
			self.fileHandle = try FileHandle(forReadingFrom: fileURL)
		} catch {
			throw UploadError.fileReadError(error)
		}
    }
    
    /// Read a specific chunk from the file
    /// - Parameters:
    ///   - index: Zero-based chunk index (0 for first chunk, 1 for second, etc.)
    ///   - chunkSize: Size of each chunk in bytes
    /// - Returns: Data for the requested chunk (may be smaller than chunkSize for last chunk)
    /// - Throws: UploadError if read fails
    func readChunk(at index: Int, chunkSize: Int64) throws -> Data {
        let offset = Int64(index) * chunkSize
        let remainingBytes = fileSize - offset
        let bytesToRead = min(chunkSize, remainingBytes)
        
        guard bytesToRead > 0 else {
            throw UploadError.invalidChunkIndex
        }
        
        do {
            // Seek to the chunk's position in the file
            try fileHandle.seek(toOffset: UInt64(offset))
            
            // Read the chunk data
            let data = fileHandle.readData(ofLength: Int(bytesToRead))
            
            guard !data.isEmpty else {
                throw UploadError.chunkReadFailed
            }
            
            return data
        } catch {
            throw UploadError.chunkReadFailed
        }
    }
    
    /// Calculate the actual size of a specific chunk
    /// (last chunk may be smaller than standard chunk size)
    func chunkSize(at index: Int, standardChunkSize: Int64) -> Int64 {
        let offset = Int64(index) * standardChunkSize
        let remainingBytes = fileSize - offset
        return min(standardChunkSize, remainingBytes)
    }
    
	/// Close the file handle
	func close() {
		do {
			try fileHandle.close()
		} catch {
			// Silently ignore close errors
		}
	}
    
    deinit {
        close()
    }
    
    // MARK: - Helper
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

