import SwiftUI

@MainActor
@Observable
final class StatsViewModel {
    var stats: StatsResponse?
    var subjectStats: [SubjectStat] = []
    var scoreHistory: [ScoreHistoryItem] = []
    var attempts: [QuizAttemptItem] = []
    var isLoading = false
    var errorMessage: String?

    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil

        do {
            async let statsTask = api.fetchStats()
            async let subjectsTask = api.fetchSubjectStats()
            async let historyTask = api.fetchScoreHistory()
            async let attemptsTask = api.fetchAttempts()

            stats = try await statsTask
            subjectStats = try await subjectsTask.subjects
            scoreHistory = try await historyTask.history
            attempts = try await attemptsTask
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
