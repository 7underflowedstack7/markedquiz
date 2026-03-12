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

struct DatabaseTableInfo: Codable, Sendable {
    let name: String
    let rowCount: Int

    enum CodingKeys: String, CodingKey {
        case name
        case rowCount = "row_count"
    }
}

struct DatabaseInfo: Codable, Sendable {
    let tables: [DatabaseTableInfo]
    let totalRows: Int

    enum CodingKeys: String, CodingKey {
        case tables
        case totalRows = "total_rows"
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
