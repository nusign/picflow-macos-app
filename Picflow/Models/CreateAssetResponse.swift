struct CreateAssetResponse: Decodable {
    let id: String
    let version: String
    let versionData: VersionData
    
    struct VersionData: Decodable {
        let id: String
        let uuid: String?  // May not always be present
        let status: String
        let tenant: String
        let amzFields: [String: String]
        let uploadUrl: String
        let originalKey: String?  // May not always be present
    }
} 