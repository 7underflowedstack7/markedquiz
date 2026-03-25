import Foundation

// MARK: - Models

struct QuizResultItem: Codable, Identifiable {
    let id: Int
    let quizName: String
    let score: Int
    let totalQuestions: Int
    let percentage: Double
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, score, percentage
        case quizName = "quiz_name"
        case totalQuestions = "total_questions"
        case completedAt = "completed_at"
    }
}

struct QuizStats: Codable {
    let totalCompleted: Int
    let averageScore: Double
    let bestScore: Double
    let totalQuestionsAnswered: Int
    let recent: [QuizResultItem]

    enum CodingKeys: String, CodingKey {
        case recent
        case totalCompleted = "total_completed"
        case averageScore = "average_score"
        case bestScore = "best_score"
        case totalQuestionsAnswered = "total_questions_answered"
    }
}

// MARK: - Service

@Observable
@MainActor
final class QuizStatsService {
    private(set) var stats: QuizStats?
    private(set) var isLoading = false

    private let baseURL = "https://markedquiz.onrender.com/api/quiz-stats"

    func fetchSummary(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/summary") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            stats = try JSONDecoder.iso8601.decode(QuizStats.self, from: data)
        } catch { }
    }

    var averageScore: Double { stats?.averageScore ?? 0 }
    var totalCompleted: Int { stats?.totalCompleted ?? 0 }
    var bestScore: Double { stats?.bestScore ?? 0 }
}
