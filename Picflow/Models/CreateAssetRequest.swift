struct CreateAssetRequest: Encodable {
    let gallery: String
    let section: String?
    let assetName: String
    let contentLength: Int
    let visibility: String
    let position: Int
    let uploadType: String
    let accelerated: Bool
    
    init(gallery: String, section: String? = nil, assetName: String, contentLength: Int, uploadType: UploadType = .post) {
        self.gallery = gallery
        self.section = section
        self.assetName = assetName
        self.contentLength = contentLength
        self.visibility = "public"
        self.position = 0
        self.uploadType = uploadType.rawValue
        self.accelerated = true
    }
    
    enum UploadType: String {
        case post = "post"
        case multipart = "multipart"
    }
    
    private enum CodingKeys: String, CodingKey {
        case gallery, section, visibility, position, accelerated
        case assetName = "asset_name"
        case contentLength = "content_length"
        case uploadType = "upload_type"
    }
} 