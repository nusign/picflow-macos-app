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
        let uuid: String
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
        title ?? name ?? "Untitled Gallery"
    }
    
    var assetCount: Int {
        totalAssetsCount ?? 0
    }
    
    var previewImageUrl: URL? {
        guard let uuid = teaser?.uuid, !uuid.isEmpty else { return nil }
        return URL(string: "https://picflow.media/images/resized/480x/\(uuid).jpg")
    }
}