import Foundation

// MARK: - Auth Models

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
    }
}

struct UserResponse: Codable {
    let id: Int
    let email: String
    let isActive: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, email
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - File Models

struct FileRecord: Codable, Identifiable {
    let id: Int
    let filename: String
    let `extension`: String
    let folder: String
    let path: String
    let sizeBytes: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, filename, folder, path
        case `extension` = "extension"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FileDetail: Codable, Identifiable {
    let id: Int
    let filename: String
    let `extension`: String
    let content: String
    let folder: String
    let path: String
    let sizeBytes: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, filename, content, folder, path
        case `extension` = "extension"
        case sizeBytes = "size_bytes"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FileCreate: Codable {
    let filename: String
    var content: String = ""
    var folder: String = ""
    var path: String = ""
}

struct FileUpdatePayload: Codable {
    var filename: String?
    var content: String?
    var folder: String?
    var path: String?
}
