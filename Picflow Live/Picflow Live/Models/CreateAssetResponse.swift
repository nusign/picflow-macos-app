struct CreateAssetResponse: Decodable {
    let id: String
    let version: String
    let versionData: VersionData
    
    struct VersionData: Decodable {
        let id: String
        let uuid: String
        let status: String
        let tenant: String
        let amzFields: [String: String]
        let uploadUrl: String
        let originalKey: String
        
        private enum CodingKeys: String, CodingKey {
            case id, uuid, status, tenant
            case amzFields = "amz_fields"
            case uploadUrl = "upload_url"
            case originalKey = "original_key"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case versionData = "version_data"
    }
} 