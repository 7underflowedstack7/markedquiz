import Foundation

struct QuestionOption: Codable, Identifiable, Sendable {
    let id: String
    let text: String
}

struct Question: Codable, Identifiable, Sendable {
    let id: String
    let type: String
    let question: String
    let options: [QuestionOption]
    let correctAnswer: String
    let explanation: String
    let sourceSection: String

    enum CodingKeys: String, CodingKey {
        case id, type, question, options, explanation
        case correctAnswer = "correct_answer"
        case sourceSection = "source_section"
    }
}

struct QuizDetail: Codable, Identifiable, Sendable {
    let id: Int
    let documentId: Int
    let title: String
    let questions: [Question]
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, questions
        case documentId = "document_id"
        case createdAt = "created_at"
    }
}

struct AnswerSubmission: Codable, Sendable {
    let questionId: String
    let userAnswer: String

    enum CodingKeys: String, CodingKey {
        case questionId = "question_id"
        case userAnswer = "user_answer"
    }
}

struct QuizSubmission: Codable, Sendable {
    let answers: [AnswerSubmission]
}

struct AnswerResult: Codable, Identifiable, Sendable {
    let questionId: String
    let question: String
    let userAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
    let explanation: String

    var id: String { questionId }

    enum CodingKeys: String, CodingKey {
        case question, explanation
        case questionId = "question_id"
        case userAnswer = "user_answer"
        case correctAnswer = "correct_answer"
        case isCorrect = "is_correct"
    }
}

struct QuizResult: Codable, Sendable {
    let quizId: Int
    let score: Int
    let total: Int
    let percentage: Double
    let xpEarned: Int
    let results: [AnswerResult]

    enum CodingKeys: String, CodingKey {
        case score, total, percentage, results
        case quizId = "quiz_id"
        case xpEarned = "xp_earned"
    }
}

struct QuizAttemptItem: Codable, Identifiable, Sendable {
    let id: Int
    let quizId: Int
    let documentTitle: String
    let score: Int
    let total: Int
    let percentage: Double
    let xpEarned: Int
    let completedAt: String

    enum CodingKeys: String, CodingKey {
        case id, score, total, percentage
        case quizId = "quiz_id"
        case documentTitle = "document_title"
        case xpEarned = "xp_earned"
        case completedAt = "completed_at"
    }
}
