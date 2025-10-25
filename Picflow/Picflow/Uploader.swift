//
//  Uploader.swift
//  Picflow
//
//  Created by Michel Luarasi on 26.01.2025.
//

import Foundation
import SwiftUI
// TODO: Uncomment after adding Sentry SDK
// import Sentry

enum UploadState {
	case idle
	case uploading
	case completed
	case failed
}

@MainActor
class Uploader: ObservableObject {
	@Published var selectedGallery: GalleryDetails?
	@Published var selectedSection: String?
	@Published var uploadProgress: Double = 0.0
	@Published var isUploading: Bool = false
	@Published var uploadState: UploadState = .idle
	
	func selectGallery(_ gallery: GalleryDetails) {
		selectedGallery = gallery
		selectedSection = gallery.section
	}
	
	/// Upload a file to the selected gallery
	func upload(fileURL: URL) async throws {
		guard let gallery = selectedGallery else {
			throw UploadError.noGallerySelected
		}
		
		// Use selectedSection if available, otherwise use gallery's default section or "default"
		let section = selectedSection ?? gallery.section ?? "default"
		
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
		
		isUploading = true
		uploadProgress = 0.0
		uploadState = .uploading
		
		defer {
			Task { @MainActor in
				isUploading = false
				uploadProgress = 0.0
			}
		}
		
		do {
			// Sentry breadcrumb: Upload started
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.addBreadcrumb(crumb: Breadcrumb(
				level: .info,
				category: "upload"
			).apply {
				$0.message = "Upload started"
				$0.data = [
					"file_name": fileURL.lastPathComponent,
					"file_size": fileData.count,
					"gallery_id": gallery.id,
					"section": section
				]
			})
			*/
			
			// Step 1: Create asset and get presigned URL
			let createAssetRequest = CreateAssetRequest(
				gallery: gallery.id,
				section: section,
				assetName: fileURL.lastPathComponent,
				contentLength: fileData.count
			)
			
			let endpoint = Endpoint(
				path: "/assets",
				httpMethod: .post,
				requestBody: createAssetRequest
			)
			
			let createResponse: CreateAssetResponse = try await endpoint.response()
			
			uploadProgress = 0.3
			
			// Sentry breadcrumb: Asset created
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.addBreadcrumb(crumb: Breadcrumb(
				level: .info,
				category: "upload"
			).apply {
				$0.message = "Asset created, starting S3 upload"
				$0.data = [
					"asset_id": createResponse.id,
					"version_id": createResponse.version
				]
			})
			*/
			
			// Step 2: Upload file to S3 using presigned URL
			try await uploadToS3(
				fileData: fileData,
				uploadURL: createResponse.versionData.uploadUrl,
				fields: createResponse.versionData.amzFields
			)
			
			uploadProgress = 1.0
			uploadState = .completed
			
			print("✅ Upload completed successfully for: \(fileURL.lastPathComponent)")
			
			// Sentry breadcrumb: Upload completed
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.addBreadcrumb(crumb: Breadcrumb(
				level: .info,
				category: "upload"
			).apply {
				$0.message = "Upload completed successfully"
			})
			*/
			
			// Reset to idle after showing success
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 3_000_000_000)
				uploadState = .idle
			}
		} catch {
			uploadState = .failed
			
			print("❌ Upload failed for: \(fileURL.lastPathComponent) - Error: \(error)")
			
			// Report to Sentry with context
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.capture(error: error) { scope in
				scope.setContext(value: [
					"file_name": fileURL.lastPathComponent,
					"file_size": fileData.count,
					"gallery_id": gallery.id,
					"section": section,
					"upload_type": "post"
				], key: "upload")
				
				scope.setTag(value: "upload", key: "operation")
				scope.setTag(value: gallery.id, key: "gallery_id")
			}
			*/
			
			// Reset to idle after showing error
			Task { @MainActor in
				try? await Task.sleep(nanoseconds: 5_000_000_000)
				uploadState = .idle
			}
			
			throw error
		}
	}
	
	/// Upload file data to S3 using presigned URL with multipart form data
	private func uploadToS3(fileData: Data, uploadURL: String, fields: [String: String]) async throws {
		guard let url = URL(string: uploadURL) else {
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.capture(message: "Invalid S3 upload URL") { scope in
				scope.setLevel(.error)
				scope.setContext(value: ["upload_url": uploadURL], key: "upload")
			}
			*/
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
			// S3 upload failed - report to Sentry
			// TODO: Uncomment after adding Sentry SDK
			/*
			SentrySDK.capture(message: "S3 upload failed") { scope in
				scope.setLevel(.error)
				scope.setContext(value: [
					"status_code": (response as? HTTPURLResponse)?.statusCode ?? 0,
					"file_size": fileData.count
				], key: "s3_upload")
			}
			*/
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
