import Foundation

struct StatsResponse: Codable, Sendable {
    let totalXp: Int
    let level: Int
    let xpForNextLevel: Int
    let xpProgressInLevel: Int
    let quizzesCompleted: Int
    let streakDays: Int
    let bestStreak: Int
    let averageScore: Double
    let lastActive: String?

    enum CodingKeys: String, CodingKey {
        case level
        case totalXp = "total_xp"
        case xpForNextLevel = "xp_for_next_level"
        case xpProgressInLevel = "xp_progress_in_level"
        case quizzesCompleted = "quizzes_completed"
        case streakDays = "streak_days"
        case bestStreak = "best_streak"
        case averageScore = "average_score"
        case lastActive = "last_active"
    }
}

struct SubjectStat: Codable, Identifiable, Sendable {
    let documentTitle: String
    let attempts: Int
    let bestScore: Double
    let averageScore: Double
    let totalXp: Int

    var id: String { documentTitle }

    enum CodingKeys: String, CodingKey {
        case attempts
        case documentTitle = "document_title"
        case bestScore = "best_score"
        case averageScore = "average_score"
        case totalXp = "total_xp"
    }
}

struct SubjectStatsResponse: Codable, Sendable {
    let subjects: [SubjectStat]
}

struct ScoreHistoryItem: Codable, Identifiable, Sendable {
    let date: String
    let score: Double
    let documentTitle: String

    var id: String { "\(date)-\(documentTitle)-\(score)" }

    enum CodingKeys: String, CodingKey {
        case date, score
        case documentTitle = "document_title"
    }
}

struct ScoreHistoryResponse: Codable, Sendable {
    let history: [ScoreHistoryItem]
}
