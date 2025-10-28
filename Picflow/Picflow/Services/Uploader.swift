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
			print("⚠️ No new files to upload (duplicates ignored)")
			return
		}
		
		uploadQueue.append(contentsOf: newFiles)
		print("📋 Queued \(newFiles.count) files for upload")
		
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
		
		print("🚀 Starting upload of \(uploadQueue.count) files")
		
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
				print("❌ Failed to upload \(fileURL.lastPathComponent): \(error)")
				
				// Track upload failure
				if let galleryId = selectedGallery?.id {
					AnalyticsManager.shared.trackUploadFailed(
						fileName: fileURL.lastPathComponent,
						error: error.localizedDescription,
						galleryId: galleryId
					)
				}
				
				// Capture error to Sentry
				ErrorReportingManager.shared.reportUploadError(
					error,
					fileName: fileURL.lastPathComponent,
					galleryId: self.selectedGallery?.id,
					additionalContext: [
						"file_path": fileURL.path,
						"gallery_name": self.selectedGallery?.displayName ?? "unknown",
						"file_index": index,
						"total_files": self.uploadQueue.count
					]
				)
				
				// Continue with next file even if one fails
			}
		}
		
		print("✅ Upload queue completed")
		
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
		uploadSpeed = 0
		estimatedTimeRemaining = 0
	}
	
	/// Upload a file to the selected gallery
	func upload(fileURL: URL) async throws {
		guard let gallery = selectedGallery else {
			throw UploadError.noGallerySelected
		}
		
		print("📤 Uploading to gallery: \(gallery.displayName)")
		
		// Check if file exists and is readable
		guard FileManager.default.fileExists(atPath: fileURL.path) else {
			throw UploadError.fileNotFound
		}
		
		let fileData: Data
		do {
			fileData = try Data(contentsOf: fileURL)
		} catch {
			throw UploadError.fileReadError(error)
		}
		
		uploadProgress = 0.0
		
		do {
			// Step 1: Create asset and get presigned URL
			let createAssetRequest = CreateAssetRequest(
				gallery: gallery.id,
				assetName: fileURL.lastPathComponent,
				contentLength: fileData.count
			)
			
			let endpoint = Endpoint(
				path: "/v1/assets",
				httpMethod: .post,
				requestBody: createAssetRequest
			)
			
			let createResponse: CreateAssetResponse = try await endpoint.response()
			
			uploadProgress = 0.3
			
			// Step 2: Upload file to S3 using presigned URL
			try await uploadToS3(
				fileData: fileData,
				uploadURL: createResponse.versionData.uploadUrl,
				fields: createResponse.versionData.amzFields
			)
			
			// Update statistics
			totalBytesTransferred += Int64(fileData.count)
			updateUploadStatistics()
			
			uploadProgress = 1.0
			
			// Track individual file upload
			AnalyticsManager.shared.trackFileUploaded(
				fileName: fileURL.lastPathComponent,
				fileSize: fileData.count,
				galleryId: gallery.id
			)
			
			// Sentry breadcrumb: File uploaded successfully
			ErrorReportingManager.shared.addBreadcrumb(
				"File uploaded successfully",
				category: "upload",
				level: .info,
				data: [
					"file_name": fileURL.lastPathComponent,
					"file_size": fileData.count,
					"gallery_id": gallery.id
				]
			)
			
			print("✅ Upload completed successfully for: \(fileURL.lastPathComponent)")
		} catch {
			print("❌ Upload failed for: \(fileURL.lastPathComponent) - Error: \(error)")
			
			// Capture detailed error to Sentry
			ErrorReportingManager.shared.reportUploadError(
				error,
				fileName: fileURL.lastPathComponent,
				fileSize: fileData.count,
				galleryId: self.selectedGallery?.id,
				additionalContext: [
					"file_path": fileURL.path,
					"gallery_name": self.selectedGallery?.displayName ?? "unknown"
				]
			)
			
			throw error
		}
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
	
	/// Upload file data to S3 using presigned URL with multipart form data
	private func uploadToS3(fileData: Data, uploadURL: String, fields: [String: String]) async throws {
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
