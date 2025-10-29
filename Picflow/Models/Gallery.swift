import Foundation

struct GalleryResponse: Decodable {
    let data: [GalleryDetails]
}

struct GalleryDetails: Codable, Equatable {
    struct Teaser: Codable, Equatable {
        let uuid: String?
        let position: String?
        let width: Int?
        let height: Int?
        let format: String?
        let ext: String?
    }
    
    struct Cover: Codable, Equatable {
        let size: String?
        let uuid: String?  // Optional - not always present in API response
        let position: String?
        let overlayColor: String?
        let contentPosition: [Double]?
        // Using automatic .convertFromSnakeCase - no explicit CodingKeys needed
    }
    
    let id: String
    let title: String?
    let name: String?
    let path: String
    let description: String?
    let folder: String?
    let teaser: Teaser?
    let cover: Cover?
    let totalAssetsCount: Int?
    
    // Note: Using automatic .convertFromSnakeCase from Endpoint.decoder
    // So we DON'T need explicit mappings for snake_case properties
    // The decoder automatically converts: total_assets_count → totalAssetsCount, etc.
    
    var displayName: String {
        title ?? name ?? "Untitled"
    }
    
    var assetCount: Int {
        totalAssetsCount ?? 0
    }
    
    var previewImageUrl: URL? {
        guard let uuid = teaser?.uuid, !uuid.isEmpty else { return nil }
        
        // Gallery teasers are served from picflow.media CDN
        // Note: This is separate from assets.picflow.io (which serves tenant logos, etc.)
        let mediaDomain: String
        switch EnvironmentManager.shared.current {
        case .development:
            mediaDomain = "https://dev.picflow.media"  // DEV media CDN
        case .production:
            mediaDomain = "https://picflow.media"  // PROD media CDN
        }
        
        return URL(string: "\(mediaDomain)/images/resized/l640/\(uuid).jpg")
    }
}