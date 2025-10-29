struct CreateAssetResponse: Decodable {
    let id: String
    let version: String
    let versionData: VersionData
    
    struct VersionData: Decodable {
        let id: String
        let uuid: String?
        let status: String
        let tenant: String
        let originalKey: String?
        
        // Single-part upload fields (POST with form data)
        let amzFields: [String: String]?
        let uploadUrl: String?
        
        // Multi-part upload fields (PUT with binary data)
        private let uploadUrls: [UploadUrlObject]?
        let uploadId: String?
        
        /// Backend returns upload URLs as objects with an "upload_url" property
        struct UploadUrlObject: Decodable {
            let uploadUrl: String
        }
        
        /// Determines if this is a multi-part upload
        var isMultiPart: Bool {
            uploadUrls != nil && (uploadUrls?.count ?? 0) > 1
        }
        
        /// Returns the appropriate upload URLs based on upload type
        var urls: [String] {
            if let uploadUrls = uploadUrls {
                return uploadUrls.map { $0.uploadUrl }
            } else if let uploadUrl = uploadUrl {
                return [uploadUrl]
            }
            return []
        }
    }
} 