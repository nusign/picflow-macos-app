import Foundation

enum EndpointError: LocalizedError {
    case unauthorized
    case urlConstructionFailed
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Not authenticated"
        case .urlConstructionFailed:
            return "Failed to construct URL"
        case .invalidResponse:
            return "Invalid server response"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        }
    }
} 
