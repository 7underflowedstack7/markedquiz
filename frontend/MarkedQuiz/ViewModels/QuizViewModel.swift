import SwiftUI

@MainActor
@Observable
final class QuizViewModel {
    var quiz: QuizDetail?
    var currentQuestionIndex = 0
    var userAnswers: [String: String] = [:]
    var fillBlankText: String = ""
    var quizResult: QuizResult?
    var isLoading = false
    var isSubmitting = false
    var errorMessage: String?
    var showingResults = false

    private let api: APIClientProtocol

    init(api: APIClientProtocol = APIClient()) {
        self.api = api
    }

    var currentQuestion: Question? {
        guard let quiz = quiz, currentQuestionIndex < quiz.questions.count else { return nil }
        return quiz.questions[currentQuestionIndex]
    }

    var totalQuestions: Int {
        quiz?.questions.count ?? 0
    }

    var isLastQuestion: Bool {
        currentQuestionIndex >= totalQuestions - 1
    }

    var progress: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(currentQuestionIndex + 1) / Double(totalQuestions)
    }

    var currentAnswerSelected: Bool {
        guard let q = currentQuestion else { return false }
        if q.type == "free_response" || q.type == "fill_blank" {
            return !fillBlankText.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return userAnswers[q.id] != nil
    }

    func generateQuiz(documentId: Int) async {
        isLoading = true
        errorMessage = nil
        currentQuestionIndex = 0
        userAnswers = [:]
        fillBlankText = ""
        quizResult = nil
        showingResults = false

        do {
            quiz = try await api.generateQuiz(documentId: documentId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func selectAnswer(_ answerId: String) {
        guard let q = currentQuestion else { return }
        userAnswers[q.id] = answerId
    }

    func saveFillBlankAnswer() {
        guard let q = currentQuestion else { return }
        userAnswers[q.id] = fillBlankText.trimmingCharacters(in: .whitespaces)
    }

    func nextQuestion() {
        if let q = currentQuestion, q.type == "fill_blank" || q.type == "free_response" {
            saveFillBlankAnswer()
        }
        fillBlankText = ""
        if currentQuestionIndex < totalQuestions - 1 {
            currentQuestionIndex += 1
            if let q = currentQuestion, q.type == "fill_blank" || q.type == "free_response",
               let existing = userAnswers[q.id] {
                fillBlankText = existing
            }
        }
    }

    func previousQuestion() {
        if let q = currentQuestion, q.type == "fill_blank" || q.type == "free_response" {
            saveFillBlankAnswer()
        }
        fillBlankText = ""
        if currentQuestionIndex > 0 {
            currentQuestionIndex -= 1
            if let q = currentQuestion, q.type == "fill_blank" || q.type == "free_response",
               let existing = userAnswers[q.id] {
                fillBlankText = existing
            }
        }
    }

    func submitQuiz() async {
        guard let quiz = quiz else { return }

        if let q = currentQuestion, q.type == "fill_blank" || q.type == "free_response" {
            saveFillBlankAnswer()
        }

        isSubmitting = true
        let answers = quiz.questions.map { q in
            AnswerSubmission(
                questionId: q.id,
                userAnswer: userAnswers[q.id] ?? ""
            )
        }

        do {
            quizResult = try await api.submitQuiz(quizId: quiz.id, answers: answers)
            showingResults = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }

    func reset() {
        quiz = nil
        currentQuestionIndex = 0
        userAnswers = [:]
        fillBlankText = ""
        quizResult = nil
        showingResults = false
        errorMessage = nil
    }
}
