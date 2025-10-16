import Foundation

struct GalleryResponse: Decodable {
    let data: [GalleryDetails]
}

struct GalleryDetails: Codable {
    struct Teaser: Codable {
        let uuid: String?
        let position: String?
        let width: Int?
        let height: Int?
        let format: String?
        let ext: String?
    }
    
    struct Cover: Codable {
        let size: String?
        let uuid: String
        let position: String?
        let overlayColor: String?
        let contentPosition: [Double]?
        
        enum CodingKeys: String, CodingKey {
            case size, uuid, position
            case overlayColor = "overlay_color"
            case contentPosition = "content_position"
        }
    }
    
    let id: String
    let title: String?
    let name: String?
    let path: String
    let description: String?
    let folder: String?
    let section: String?
    let position: Int?
    let colorMode: String?
    let primaryColor: String?
    let teaser: Teaser?
    let cover: Cover?
    let createdAt: Int?
    let updatedAt: Int?
    let deletedAt: Int?
    let tenant: String?
    let enabledFeedbackOptions: [String]?
    let requiresUserIdentification: Bool?
    let password: String?
    let contactsHidden: Bool?
    let saveCameraMetadata: Bool?
    
    private enum CodingKeys: String, CodingKey {
        case id, title, name, path, description, folder, section, position, teaser, cover, tenant, password
        case colorMode = "color_mode"
        case primaryColor = "primary_color"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case enabledFeedbackOptions = "enabled_feedback_options"
        case requiresUserIdentification = "requires_user_identification"
        case contactsHidden = "contacts_hidden"
        case saveCameraMetadata = "save_camera_metadata"
    }
    
    var displayName: String {
        title ?? name ?? "Untitled Gallery"
    }
    
    var previewImageUrl: URL? {
        guard let uuid = teaser?.uuid, !uuid.isEmpty else { return nil }
        return URL(string: "https://picflow.media/images/resized/480x/\(uuid).jpg")
    }
}