//
//  Uploader.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import SwiftUI
import Sentry

enum UploadState {
	case idle
	case uploading
	case completed
	case failed
}

@MainActor
class Uploader: ObservableObject {
	@Published var selectedGallery: GalleryDetails?
	@Published var uploadProgress: Double = 0.0
	@Published var isUploading: Bool = false
	@Published var uploadState: UploadState = .idle
	
	// Upload statistics
	@Published var uploadQueue: [URL] = []
	@Published var currentFileIndex: Int = 0
	@Published var uploadSpeed: Double = 0.0  // bytes per second
	@Published var estimatedTimeRemaining: TimeInterval = 0
	
	private var uploadStartTime: Date?
	private var totalBytesTransferred: Int64 = 0
	private var totalFilesInQueue: Int = 0  // Track total files at queue start for progress calculation
	
	func selectGallery(_ gallery: GalleryDetails) {
		selectedGallery = gallery
		print("🎨 Gallery selected: \(gallery.displayName)")
	}
	
	/// Queue multiple files for upload
	func queueFiles(_ urls: [URL]) {
		// Filter out duplicates
		let newFiles = urls.filter { url in
			!uploadQueue.contains(where: { $0.path == url.path })
		}
		
		guard !newFiles.isEmpty else {
			return
		}
		
		uploadQueue.append(contentsOf: newFiles)
		
		// Start processing if not already running
		if !isUploading {
			Task {
				await processQueue()
			}
		}
	}
	
	/// Process upload queue
	private func processQueue() async {
		guard !uploadQueue.isEmpty, !isUploading else { return }
		
		isUploading = true
		uploadState = .uploading
		uploadStartTime = Date()
		totalBytesTransferred = 0
		currentFileIndex = 0
		totalFilesInQueue = uploadQueue.count  // Store total for progress calculation
		uploadProgress = 0.0
		
		if uploadQueue.count > 1 {
			print("\n🚀 UPLOAD QUEUE: \(uploadQueue.count) files")
		}
		
		// Track upload started
		if let galleryId = selectedGallery?.id {
			AnalyticsManager.shared.trackUploadStarted(fileCount: uploadQueue.count, galleryId: galleryId)
		}
		
		// Sentry breadcrumb: Upload started
		ErrorReportingManager.shared.addBreadcrumb(
			"Upload started",
			category: "upload",
			level: .info,
			data: [
				"file_count": uploadQueue.count,
				"gallery_id": selectedGallery?.id ?? "unknown"
			]
		)
		
		for (index, fileURL) in uploadQueue.enumerated() {
			currentFileIndex = index
			do {
				try await upload(fileURL: fileURL)
			} catch {
				// Track upload failure
				if let galleryId = selectedGallery?.id {
					AnalyticsManager.shared.trackUploadFailed(
						fileName: fileURL.lastPathComponent,
						error: error.localizedDescription,
						galleryId: galleryId
					)
				}
				
				// Capture error to Sentry
				reportUploadError(
					error,
					fileName: fileURL.lastPathComponent,
					fileIndex: index,
					additionalContext: ["file_path": fileURL.path]
				)
				
				// Continue with next file even if one fails
			}
		}
		
		if uploadQueue.count > 1 {
			print("\n✅ QUEUE COMPLETE: All \(uploadQueue.count) files processed\n")
		}
		
		// Track upload completion
		if let startTime = uploadStartTime, let galleryId = selectedGallery?.id {
			let duration = Date().timeIntervalSince(startTime)
			AnalyticsManager.shared.trackUploadCompleted(
				fileCount: uploadQueue.count,
				totalSize: totalBytesTransferred,
				duration: duration,
				galleryId: galleryId
			)
		}
		
		// Show completed state briefly, then reset
		uploadState = .completed
		
		// Wait before clearing
		try? await Task.sleep(nanoseconds: 2_000_000_000)
		
		// Clear queue and reset state
		uploadQueue.removeAll()
		isUploading = false
		uploadState = .idle
		uploadStartTime = nil
		currentFileIndex = 0
		totalBytesTransferred = 0
		totalFilesInQueue = 0
		uploadSpeed = 0
		estimatedTimeRemaining = 0
	}
	
	/// Upload a file to the selected gallery
	func upload(fileURL: URL) async throws {
		guard let gallery = selectedGallery else {
			throw UploadError.noGallerySelected
		}
		
		// Check if file exists and is readable
		guard FileManager.default.fileExists(atPath: fileURL.path) else {
			throw UploadError.fileNotFound
		}
		
		// Get file size to determine upload strategy
		let fileSize: Int64
		do {
			let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
			fileSize = attributes[.size] as? Int64 ?? 0
		} catch {
			throw UploadError.fileReadError(error)
		}
		
		// Calculate overall queue progress
		updateOverallProgress(fileProgress: 0.0)
		
		// Determine upload type based on file size
		let uploadType: CreateAssetRequest.UploadType = MultiPartUploadConfig.shouldUseMultipart(fileSize: fileSize) ? .multipart : .post
		
		print("\n📤 UPLOAD START")
		print("   File: \(fileURL.lastPathComponent)")
		print("   Size: \(formatBytes(fileSize))")
		print("   Gallery: \(gallery.displayName)")
		print("   Mode: \(uploadType == .multipart ? "Multi-part" : "Single-part")")
		
		do {
			// Step 1: Create asset and get presigned URL(s)
			let createAssetRequest = CreateAssetRequest(
				gallery: gallery.id,
				assetName: fileURL.lastPathComponent,
				contentLength: Int(fileSize),
				uploadType: uploadType
			)
			
			let endpoint = Endpoint(
				path: "/v1/assets",
				httpMethod: .post,
				requestBody: createAssetRequest
			)
			
			let createResponse: CreateAssetResponse = try await endpoint.response()
			
			updateOverallProgress(fileProgress: 0.1)
			
		// Step 2: Upload file to S3 (single or multipart)
		if createResponse.versionData.isMultiPart {
			// Multi-part uploads update totalBytesTransferred incrementally as chunks complete
			try await uploadMultiPart(
				fileURL: fileURL,
				versionData: createResponse.versionData,
				fileSize: fileSize
			)
		} else {
			// Load file into memory for single-part upload
			let fileData = try Data(contentsOf: fileURL)
			try await uploadSinglePart(
				fileData: fileData,
				uploadURL: createResponse.versionData.uploadUrl ?? "",
				fields: createResponse.versionData.amzFields ?? [:]
			)
			
			// Update statistics for single-part uploads
			// (multi-part uploads handle this incrementally)
			totalBytesTransferred += fileSize
			updateUploadStatistics()
		}
		
		updateOverallProgress(fileProgress: 1.0)
		
		// Track individual file upload
		AnalyticsManager.shared.trackFileUploaded(
			fileName: fileURL.lastPathComponent,
			fileSize: Int(fileSize),
			galleryId: gallery.id
		)
		
		// Sentry breadcrumb: File uploaded successfully
		ErrorReportingManager.shared.addBreadcrumb(
			"File uploaded successfully",
			category: "upload",
			level: .info,
			data: [
				"file_name": fileURL.lastPathComponent,
				"file_size": Int(fileSize),
				"gallery_id": gallery.id,
				"upload_type": uploadType.rawValue
			]
		)
		
		print("✅ UPLOAD COMPLETE: \(fileURL.lastPathComponent)\n")
		} catch {
			print("❌ UPLOAD FAILED: \(fileURL.lastPathComponent)")
			print("   Error: \(error.localizedDescription)\n")
			
			// Capture detailed error to Sentry
			reportUploadError(
				error,
				fileName: fileURL.lastPathComponent,
				fileSize: Int(fileSize),
				additionalContext: ["file_path": fileURL.path]
			)
			
			throw error
		}
	}
	
	/// Calculate overall progress across all files in queue
	/// - Parameter fileProgress: Progress of current file (0.0 to 1.0)
	private func updateOverallProgress(fileProgress: Double) {
		guard totalFilesInQueue > 0 else {
			uploadProgress = fileProgress
			return
		}
		
		// Calculate base progress from completed files
		let filesCompleted = Double(currentFileIndex)
		let fileWeight = 1.0 / Double(totalFilesInQueue)
		
		// Overall progress = completed files + current file progress
		uploadProgress = (filesCompleted * fileWeight) + (fileProgress * fileWeight)
	}
	
	/// Update upload statistics (speed and time remaining)
	private func updateUploadStatistics() {
		guard let startTime = uploadStartTime else { return }
		
		let elapsedTime = Date().timeIntervalSince(startTime)
		guard elapsedTime > 0 else { return }
		
		// Calculate speed (bytes per second)
		uploadSpeed = Double(totalBytesTransferred) / elapsedTime
		
		// Estimate remaining time based on remaining files
		let remainingFiles = uploadQueue.count - currentFileIndex - 1
		if remainingFiles > 0, uploadSpeed > 0 {
			// Rough estimate: assume similar file sizes
			let avgBytesPerFile = Double(totalBytesTransferred) / Double(currentFileIndex + 1)
			let remainingBytes = avgBytesPerFile * Double(remainingFiles)
			estimatedTimeRemaining = remainingBytes / uploadSpeed
		} else {
			estimatedTimeRemaining = 0
		}
	}
	
	/// Upload file data to S3 using presigned URL with multipart form data (single-part upload)
	private func uploadSinglePart(fileData: Data, uploadURL: String, fields: [String: String]) async throws {
		guard let url = URL(string: uploadURL) else {
			throw UploadError.invalidUploadURL
		}
		
		// Create multipart form data
		let boundary = "Boundary-\(UUID().uuidString)"
		var body = Data()
		
		// Add all form fields
		for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
			body.append("--\(boundary)\r\n")
			body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
			body.append("\(value)\r\n")
		}
		
		// Add file data
		body.append("--\(boundary)\r\n")
		body.append("Content-Disposition: form-data; name=\"file\"; filename=\"file\"\r\n")
		body.append("Content-Type: application/octet-stream\r\n\r\n")
		body.append(fileData)
		body.append("\r\n")
		body.append("--\(boundary)--\r\n")
		
		// Create request
		var request = URLRequest(url: url)
		request.httpMethod = "POST"
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		request.httpBody = body
		
		let (_, response) = try await URLSession.shared.data(for: request)
		
		guard let httpResponse = response as? HTTPURLResponse,
		      200...299 ~= httpResponse.statusCode else {
			throw UploadError.s3UploadFailed
		}
		
		updateOverallProgress(fileProgress: 0.9)
	}
	
	/// Upload file using multipart upload (for large files)
	private func uploadMultiPart(
		fileURL: URL,
		versionData: CreateAssetResponse.VersionData,
		fileSize: Int64
	) async throws {
		let uploadUrls = versionData.urls
		guard !uploadUrls.isEmpty else {
			throw UploadError.invalidUploadURL
		}
		
		guard let uploadId = versionData.uploadId else {
			throw UploadError.missingUploadId
		}
		
		guard let originalKey = versionData.originalKey else {
			throw UploadError.missingOriginalKey
		}
		
		// Calculate chunk size based on file size and part count
		let chunkSize = MultiPartUploadConfig.calculateChunkSize(
			fileSize: fileSize,
			partCount: uploadUrls.count
		)
		
		print("   Uploading in \(uploadUrls.count) parts (\(formatBytes(chunkSize)) each)")
		
		// Create file reader for streaming from disk
		let reader = try ChunkedFileReader(fileURL: fileURL)
		defer { reader.close() }
		
		// Track uploaded parts with their ETags
		var uploadedParts: [CompleteMultipartUploadRequest.Part] = []
		
		// Upload chunks with limited concurrency
		try await withThrowingTaskGroup(of: (Int, String, Int64).self) { group in
			var activeUploads = 0
			let maxConcurrent = MultiPartUploadConfig.maxConcurrentUploads
			
			for (index, uploadURL) in uploadUrls.enumerated() {
				// Wait if we've reached max concurrent uploads
				while activeUploads >= maxConcurrent {
					let (completedIndex, etag, bytesUploaded) = try await group.next()!
					activeUploads -= 1
					
					// Store the completed part
					uploadedParts.append(CompleteMultipartUploadRequest.Part(
						etag: etag,
						partNumber: completedIndex + 1  // S3 part numbers are 1-based
					))
					
					// Update bytes transferred and statistics
					await MainActor.run {
						self.totalBytesTransferred += bytesUploaded
						self.updateUploadStatistics()
					}
					
					// Update progress (10% reserved for initial setup, 85% for uploads, 5% for completion)
					let fileProgress = 0.1 + (0.85 * Double(uploadedParts.count) / Double(uploadUrls.count))
					await MainActor.run {
						self.updateOverallProgress(fileProgress: fileProgress)
					}
				}
				
				// Read chunk from disk
				let chunkData = try reader.readChunk(at: index, chunkSize: chunkSize)
				let chunkDataSize = Int64(chunkData.count)
				
				// Upload chunk in background
				group.addTask {
					let etag = try await self.uploadChunk(
						data: chunkData,
						uploadURL: uploadURL,
						partNumber: index + 1,
						attempt: 0
					)
					return (index, etag, chunkDataSize)
				}
				activeUploads += 1
			}
			
			// Wait for remaining uploads to complete
			while let (completedIndex, etag, bytesUploaded) = try await group.next() {
				uploadedParts.append(CompleteMultipartUploadRequest.Part(
					etag: etag,
					partNumber: completedIndex + 1
				))
				
				// Update bytes transferred and statistics
				await MainActor.run {
					self.totalBytesTransferred += bytesUploaded
					self.updateUploadStatistics()
				}
				
				let fileProgress = 0.1 + (0.85 * Double(uploadedParts.count) / Double(uploadUrls.count))
				await MainActor.run {
					self.updateOverallProgress(fileProgress: fileProgress)
				}
				
				// Log progress every 10% or on last chunk
				if completedIndex == 0 || uploadedParts.count % max(uploadUrls.count / 10, 1) == 0 || completedIndex == uploadUrls.count - 1 {
					print("   Progress: \(uploadedParts.count)/\(uploadUrls.count) parts (\(Int(fileProgress * 100))%)")
				}
			}
		}
		
		// Sort parts by part number (required by S3)
		uploadedParts.sort { $0.partNumber < $1.partNumber }
		
		// Update progress to show all chunks uploaded
		await MainActor.run {
			self.updateOverallProgress(fileProgress: 0.95)
		}
		
		print("   Finalizing upload...")
		
		// Complete the multipart upload
		try await completeMultipartUpload(
			key: originalKey,
			uploadId: uploadId,
			parts: uploadedParts
		)
		
		// Show 100% briefly before completion
		await MainActor.run {
			self.updateOverallProgress(fileProgress: 1.0)
		}
	}
	
	/// Upload a single chunk to S3
	private func uploadChunk(
		data: Data,
		uploadURL: String,
		partNumber: Int,
		attempt: Int
	) async throws -> String {
		guard let url = URL(string: uploadURL) else {
			throw UploadError.invalidUploadURL
		}
		
		do {
			// Create PUT request with binary data
			var request = URLRequest(url: url)
			request.httpMethod = "PUT"
			request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
			request.httpBody = data
			
			let (_, response) = try await URLSession.shared.data(for: request)
			
			guard let httpResponse = response as? HTTPURLResponse else {
				throw UploadError.s3UploadFailed
			}
			
			guard 200...299 ~= httpResponse.statusCode else {
				throw UploadError.s3UploadFailed
			}
			
			// Extract ETag from response headers
			guard let etag = httpResponse.value(forHTTPHeaderField: "ETag") else {
				throw UploadError.missingETag
			}
			
			// Remove quotes from ETag if present (S3 sometimes includes them)
			let cleanETag = etag.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
			
			return cleanETag
			
		} catch {
			// Retry logic with exponential backoff
			if attempt < MultiPartUploadConfig.maxRetryAttempts {
				let delay = MultiPartUploadConfig.retryDelay(for: attempt)
				print("   ⚠️ Part \(partNumber) failed, retrying in \(Int(delay))s... (attempt \(attempt + 2)/\(MultiPartUploadConfig.maxRetryAttempts + 1))")
				
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
				
				return try await uploadChunk(
					data: data,
					uploadURL: uploadURL,
					partNumber: partNumber,
					attempt: attempt + 1
				)
			} else {
				print("   ❌ Part \(partNumber) failed after \(MultiPartUploadConfig.maxRetryAttempts + 1) attempts")
				throw error
			}
		}
	}
	
	/// Complete the multipart upload by notifying the backend
	private func completeMultipartUpload(
		key: String,
		uploadId: String,
		parts: [CompleteMultipartUploadRequest.Part]
	) async throws {
		let request = CompleteMultipartUploadRequest(
			key: key,
			uploadId: uploadId,
			parts: parts
		)
		
		// Use custom encoder without snake_case conversion for this specific request
		// because the backend expects "ETag" and "PartNumber" exactly as specified
		let encoder = JSONEncoder()
		// Do NOT use snake_case for this request
		let requestBody = try encoder.encode(request)
		
		guard let url = URL(string: "\(Endpoint.baseURL)/v1/multipart_uploads/complete") else {
			throw UploadError.invalidUploadURL
		}
		
		var urlRequest = URLRequest(url: url)
		urlRequest.httpMethod = "POST"
		urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
		urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
		urlRequest.setValue(Endpoint.apiVersion, forHTTPHeaderField: "X-API-Version")
		
		if let token = Endpoint.token {
			urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		
		if let tenantId = Endpoint.currentTenantId {
			urlRequest.setValue(tenantId, forHTTPHeaderField: "picflow-tenant")
		}
		
		urlRequest.httpBody = requestBody
		
		let (data, response) = try await URLSession.shared.data(for: urlRequest)
		
		guard let httpResponse = response as? HTTPURLResponse else {
			throw UploadError.multipartCompletionFailed
		}
		
		guard 200...299 ~= httpResponse.statusCode else {
			print("   ❌ Completion failed with status: \(httpResponse.statusCode)")
			if let responseString = String(data: data, encoding: .utf8) {
				print("   Response: \(responseString)")
			}
			throw EndpointError.httpError(statusCode: httpResponse.statusCode)
		}
		
		// Backend returns 204 No Content on success - nothing to decode
		// Any 2xx status means the upload completed successfully
	}
	
	/// Format bytes into human-readable string
	private func formatBytes(_ bytes: Int64) -> String {
		let formatter = ByteCountFormatter()
		formatter.countStyle = .file
		return formatter.string(fromByteCount: bytes)
	}
	
	// MARK: - Error Reporting Helpers
	
	/// Report upload error with automatic gallery and queue context
	private func reportUploadError(
		_ error: Error,
		fileName: String? = nil,
		fileSize: Int? = nil,
		fileIndex: Int? = nil,
		additionalContext: [String: Any] = [:]
	) {
		var context = additionalContext
		
		// Automatically include gallery context
		if let gallery = selectedGallery {
			context["gallery_id"] = gallery.id
			context["gallery_name"] = gallery.displayName
		}
		
		// Automatically include queue info
		context["total_files"] = uploadQueue.count
		
		// Include file-specific info if provided
		if let fileName = fileName {
			context["file_name"] = fileName
		}
		if let fileSize = fileSize {
			context["file_size"] = fileSize
		}
		if let fileIndex = fileIndex {
			context["file_index"] = fileIndex
		}
		
		var tags: [String: String] = ["operation": "upload"]
		if let galleryId = selectedGallery?.id {
			tags["gallery_id"] = galleryId
		}
		
		ErrorReportingManager.shared.reportError(
			error,
			context: context,
			tags: tags
		)
	}
}

// MARK: - Upload Errors
enum UploadError: LocalizedError {
	case noGallerySelected
	case noSectionSelected
	case fileNotFound
	case fileReadError(Error)
	case invalidUploadURL
	case s3UploadFailed
	case invalidChunkIndex
	case chunkReadFailed
	case missingETag
	case multipartCompletionFailed
	case missingUploadId
	case missingOriginalKey
	
	var errorDescription: String? {
		switch self {
		case .noGallerySelected:
			return "No gallery selected. Please select a gallery before uploading."
		case .noSectionSelected:
			return "No section selected. Please select a section before uploading."
		case .fileNotFound:
			return "File not found at the specified path."
		case .fileReadError(let error):
			return "Failed to read file: \(error.localizedDescription)"
		case .invalidUploadURL:
			return "Invalid upload URL received from server."
		case .s3UploadFailed:
			return "Failed to upload file to S3."
		case .invalidChunkIndex:
			return "Invalid chunk index for file read."
		case .chunkReadFailed:
			return "Failed to read chunk from file."
		case .missingETag:
			return "Missing ETag from S3 upload response."
		case .multipartCompletionFailed:
			return "Failed to complete multipart upload."
		case .missingUploadId:
			return "Missing upload ID for multipart upload."
		case .missingOriginalKey:
			return "Missing original key for multipart upload."
		}
	}
}

// MARK: - Data Extension for Multipart
private extension Data {
	mutating func append(_ string: String) {
		if let data = string.data(using: .utf8) {
			append(data)
		}
	}
}
