import Foundation

/// Fetches quiz .md files from the backend (folders prefixed with "quiz/"),
/// parses them into Quiz structs, and manages quiz state.
@Observable
@MainActor
final class QuizService {
    private(set) var quizzes: [Quiz] = []
    private(set) var isLoading = false

    private let baseURL = "https://markedquiz.onrender.com/api/files"

    /// Fetch all files in folders starting with "quiz/" and parse them
    func fetchQuizzes(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }

        // Fetch all .md files
        guard var components = URLComponents(string: baseURL) else { return }
        components.queryItems = [URLQueryItem(name: "extension", value: "md")]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let files = try JSONDecoder.iso8601.decode([FileRecord].self, from: data)

            // Filter to quiz folders only
            let quizFiles = files.filter { $0.folder.lowercased().hasPrefix("quiz") }

            // Fetch full content for each and parse
            var parsed: [Quiz] = []
            for file in quizFiles {
                if let detail = await fetchFileDetail(id: file.id, token: token),
                   let quiz = QuizParser.parse(
                       markdown: detail.content,
                       fileId: file.id,
                       filename: file.filename,
                       folder: file.folder
                   ) {
                    parsed.append(quiz)
                }
            }
            quizzes = parsed
        } catch { }
    }

    /// Group quizzes by folder for display
    var quizzesByFolder: [(folder: String, quizzes: [Quiz])] {
        let grouped = Dictionary(grouping: quizzes) { $0.folder }
        return grouped.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    /// Total available questions across all quizzes
    var totalQuestions: Int {
        quizzes.reduce(0) { $0 + $1.questionCount }
    }

    // MARK: - Private

    private func fetchFileDetail(id: Int, token: String) async -> FileDetail? {
        guard let url = URL(string: "\(baseURL)/\(id)") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder.iso8601.decode(FileDetail.self, from: data)
        } catch { return nil }
    }
}
