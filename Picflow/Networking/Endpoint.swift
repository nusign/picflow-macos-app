import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

class Endpoint {
    // MARK: - API Configuration
    static let apiVersion = "2023-01-01"
    static let requestTimeout: TimeInterval = 30
    
    // MARK: - State
    static var baseURL: URL {
        URL(string: EnvironmentManager.shared.current.apiBaseURL)!
    }
    static var token: String?
    static var currentTenantId: String?
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()
    
    let path: String
    let httpMethod: HTTPMethod
    let requestBody: Encodable?
    let queryItems: [String: String]?
    let customURL: URL?
    
    init(path: String, httpMethod: HTTPMethod = .get, requestBody: Encodable? = nil, queryItems: [String: String]? = nil) {
        self.path = path
        self.httpMethod = httpMethod
        self.requestBody = requestBody
        self.queryItems = queryItems
        self.customURL = nil
    }
    
    init(url: URL, httpMethod: HTTPMethod = .get, body: Data? = nil) {
        self.path = ""
        self.httpMethod = httpMethod
        self.requestBody = body
        self.queryItems = nil
        self.customURL = url
    }
    
    var url: URL {
        if let customURL = customURL {
            return customURL
        }
        
        // Remove any trailing question mark and make sure path starts with /
        let cleanPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "?"))
        let pathWithLeadingSlash = cleanPath.hasPrefix("/") ? cleanPath : "/\(cleanPath)"
        
        var components = URLComponents(url: Self.baseURL.appendingPathComponent(pathWithLeadingSlash), resolvingAgainstBaseURL: true)!
        
        if let queryItems = queryItems {
            components.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        return components.url!
    }
    
    func response<T: Decodable>() async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        // Add required headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "X-API-Version")
        
        if let token = Endpoint.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let tenantId = Endpoint.currentTenantId {
            request.setValue(tenantId, forHTTPHeaderField: "picflow-tenant")
        }
        
        if let requestBody = requestBody {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let jsonData = try encoder.encode(requestBody)
            request.httpBody = jsonData
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                // Only log errors
                #if DEBUG
                print("❌ HTTP \(httpResponse.statusCode): \(httpMethod.rawValue) \(url)")
                if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                    print("   Response: \(responseString.prefix(500))")
                }
                #endif
                throw EndpointError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
        return try Self.decoder.decode(T.self, from: data)
    }
    
    func responseData() async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        if let requestBody = requestBody as? Data {
            request.httpBody = requestBody
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
        
        return data
    }
} 
