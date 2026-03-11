import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case networkError(Error)
    case serverError(Int, String)
    case decodingError(Error)
    case noData

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .decodingError(let error):
            return "Data error: \(error.localizedDescription)"
        case .noData:
            return "No data received"
        }
    }
}

protocol APIClientProtocol: Sendable {
    func fetchDocuments() async throws -> [DocumentListItem]
    func fetchDocument(id: Int) async throws -> DocumentDetail
    func uploadDocument(title: String, content: String) async throws -> DocumentDetail
    func deleteDocument(id: Int) async throws
    func generateQuiz(documentId: Int) async throws -> QuizDetail
    func fetchQuiz(id: Int) async throws -> QuizDetail
    func submitQuiz(quizId: Int, answers: [AnswerSubmission]) async throws -> QuizResult
    func fetchAttempts() async throws -> [QuizAttemptItem]
    func fetchStats() async throws -> StatsResponse
    func fetchSubjectStats() async throws -> SubjectStatsResponse
    func fetchScoreHistory() async throws -> ScoreHistoryResponse
}

final class APIClient: APIClientProtocol, Sendable {
    // Use the Mac's local IP since simulator can't use localhost
    private let baseURL: String

    init(baseURL: String = "http://127.0.0.1:8000") {
        self.baseURL = baseURL
    }

    // MARK: - Documents

    func fetchDocuments() async throws -> [DocumentListItem] {
        try await get("/api/documents")
    }

    func fetchDocument(id: Int) async throws -> DocumentDetail {
        try await get("/api/documents/\(id)")
    }

    func uploadDocument(title: String, content: String) async throws -> DocumentDetail {
        struct Body: Codable {
            let title: String
            let content: String
        }
        return try await post("/api/documents", body: Body(title: title, content: content))
    }

    func deleteDocument(id: Int) async throws {
        let _: [String: String] = try await delete("/api/documents/\(id)")
    }

    // MARK: - Quizzes

    func generateQuiz(documentId: Int) async throws -> QuizDetail {
        try await post("/api/documents/\(documentId)/quiz", body: Optional<String>.none)
    }

    func fetchQuiz(id: Int) async throws -> QuizDetail {
        try await get("/api/quizzes/\(id)")
    }

    func submitQuiz(quizId: Int, answers: [AnswerSubmission]) async throws -> QuizResult {
        try await post("/api/quizzes/\(quizId)/submit", body: QuizSubmission(answers: answers))
    }

    func fetchAttempts() async throws -> [QuizAttemptItem] {
        try await get("/api/attempts")
    }

    // MARK: - Stats

    func fetchStats() async throws -> StatsResponse {
        try await get("/api/stats")
    }

    func fetchSubjectStats() async throws -> SubjectStatsResponse {
        try await get("/api/stats/subjects")
    }

    func fetchScoreHistory() async throws -> ScoreHistoryResponse {
        try await get("/api/stats/history")
    }

    // MARK: - Generic Helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func post<T: Decodable, B: Encodable>(_ path: String, body: B?) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let body = body {
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try decode(data)
    }

    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200...299).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, message)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
