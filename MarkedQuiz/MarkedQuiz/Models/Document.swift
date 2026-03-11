import Foundation

struct DocumentListItem: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let wordCount: Int
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title
        case wordCount = "word_count"
        case createdAt = "created_at"
    }
}

struct DocumentDetail: Codable, Identifiable, Sendable {
    let id: Int
    let title: String
    let content: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, content
        case createdAt = "created_at"
    }
}
