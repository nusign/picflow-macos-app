import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

class Endpoint {
    static var baseURL = URL(string: "https://api.picflow.io")!
    static var token: String?
    static var currentTenantId: String?
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
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
        print("Making request to:", url)
        print("Method:", httpMethod)
        print("Token present:", Endpoint.token != nil)
        
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        // Add required headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-01-01", forHTTPHeaderField: "X-API-Version")
        
        if let token = Endpoint.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            print("Authorization header set to: Bearer \(token.prefix(20))...")
        }
        
        if let tenantId = Endpoint.currentTenantId {
            request.setValue(tenantId, forHTTPHeaderField: "picflow-tenant")
            print("Tenant ID header set to:", tenantId)
        }
        
        if let requestBody = requestBody {
            request.httpBody = try JSONEncoder().encode(requestBody)
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("Response status code:", httpResponse.statusCode)
            print("Response headers:", httpResponse.allHeaderFields)
            
            // Print response data as string to see what we're getting
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response body:", responseString.prefix(500))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
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
