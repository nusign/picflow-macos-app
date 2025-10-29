//
//  CompleteMultipartUploadRequest.swift
//  Picflow
//
//  Created by Michel Luarasi on 29.10.2025.
//

import Foundation

struct CompleteMultipartUploadRequest: Encodable {
    let key: String
    let uploadId: String
    let parts: [Part]
    
    struct Part: Encodable {
        let etag: String
        let partNumber: Int
        
        enum CodingKeys: String, CodingKey {
            case etag = "ETag"
            case partNumber = "PartNumber"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case key
        case uploadId = "upload_id"
        case parts
    }
}

// Note: Backend returns 204 No Content on success, so no response model needed

