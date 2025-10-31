import Foundation

struct DeleteGalleryRequest {
    let galleryId: String
    
    func endpoint() -> Endpoint {
        // Send empty JSON body to satisfy API requirement
        struct EmptyBody: Encodable {}
        
        return Endpoint(
            path: "/v1/galleries/\(galleryId)",
            httpMethod: .delete,
            requestBody: EmptyBody()
        )
    }
}

