struct CreateAssetRequest: Encodable {
    let gallery: String
    let assetName: String
    let contentLength: Int
    let visibility: String
    let position: Int
    let uploadType: String
    let accelerated: Bool
    
    init(gallery: String, assetName: String, contentLength: Int) {
        self.gallery = gallery
        self.assetName = assetName
        self.contentLength = contentLength
        self.visibility = "public"
        self.position = 0
        self.uploadType = "post"
        self.accelerated = true
    }
    
    private enum CodingKeys: String, CodingKey {
        case gallery, visibility, position, accelerated
        case assetName = "asset_name"
        case contentLength = "content_length"
        case uploadType = "upload_type"
    }
} 