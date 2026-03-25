import Foundation

// MARK: - Quiz Models

struct Quiz: Identifiable, Hashable {
    let id: Int              // FileRecord.id for reference
    let title: String
    let difficulty: String   // beginner, intermediate, advanced
    let tags: [String]
    let questions: [QuizQuestion]
    let sourceFile: String   // filename for display
    let folder: String       // e.g. "quiz/python"

    var questionCount: Int { questions.count }

    static func == (lhs: Quiz, rhs: Quiz) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let text: String
    let options: [QuizOption]
    let explanation: String?

    var correctIndex: Int? {
        options.firstIndex(where: \.isCorrect)
    }
}

struct QuizOption: Identifiable {
    let id = UUID()
    let text: String
    let isCorrect: Bool
}

// MARK: - Frontmatter

struct QuizFrontmatter {
    var title: String = "Untitled Quiz"
    var difficulty: String = "beginner"
    var tags: [String] = []
}

// MARK: - Parser

/// Parses a `.md` file in the quiz format into a `Quiz` struct.
///
/// Expected format:
/// ```
/// ---
/// title: Python Basics
/// difficulty: beginner
/// tags: python, fundamentals
/// ---
///
/// ## What is 2 + 2?
///
/// - [x] 4
/// - [ ] 5
/// - [ ] 3
/// - [ ] 22
///
/// > Two plus two equals four.
/// ```
///
/// Rules:
/// - YAML frontmatter between `---` delimiters (title, difficulty, tags)
/// - `##` heading starts a new question
/// - `- [x]` = correct answer (one per question)
/// - `- [ ]` = incorrect answer
/// - `> blockquote` = optional explanation (shown after answering)
enum QuizParser {

    static func parse(markdown: String, fileId: Int, filename: String, folder: String) -> Quiz? {
        let (frontmatter, body) = extractFrontmatter(from: markdown)
        let questions = parseQuestions(from: body)

        guard !questions.isEmpty else { return nil }

        return Quiz(
            id: fileId,
            title: frontmatter.title,
            difficulty: frontmatter.difficulty,
            tags: frontmatter.tags,
            questions: questions,
            sourceFile: filename,
            folder: folder
        )
    }

    // MARK: - Frontmatter Extraction

    private static func extractFrontmatter(from markdown: String) -> (QuizFrontmatter, String) {
        var fm = QuizFrontmatter()
        let lines = markdown.components(separatedBy: "\n")

        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (fm, markdown)
        }

        var fmLines: [String] = []
        var bodyStart = 1
        var foundClose = false

        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                bodyStart = i + 1
                foundClose = true
                break
            }
            fmLines.append(lines[i])
        }

        guard foundClose else { return (fm, markdown) }

        // Parse simple YAML key: value pairs
        for line in fmLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)

            switch key {
            case "title":
                fm.title = value
            case "difficulty":
                fm.difficulty = value.lowercased()
            case "tags":
                fm.tags = value.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespaces).lowercased()
                }
            default:
                break
            }
        }

        let body = lines[bodyStart...].joined(separator: "\n")
        return (fm, body)
    }

    // MARK: - Question Parsing

    private static func parseQuestions(from body: String) -> [QuizQuestion] {
        let lines = body.components(separatedBy: "\n")
        var questions: [QuizQuestion] = []

        var currentQuestionText: String?
        var currentOptions: [QuizOption] = []
        var currentExplanation: String?

        func flushQuestion() {
            guard let text = currentQuestionText, !currentOptions.isEmpty else { return }
            // Only include questions that have exactly one correct answer
            let correctCount = currentOptions.filter(\.isCorrect).count
            guard correctCount == 1 else { return }

            questions.append(QuizQuestion(
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                options: currentOptions,
                explanation: currentExplanation?.trimmingCharacters(in: .whitespacesAndNewlines)
            ))
            currentQuestionText = nil
            currentOptions = []
            currentExplanation = nil
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // New question: ## heading
            if trimmed.hasPrefix("## ") {
                flushQuestion()
                currentQuestionText = String(trimmed.dropFirst(3))
                continue
            }

            // Correct answer: - [x] or - [X]
            if let match = trimmed.range(of: #"^- \[[xX]\] "#, options: .regularExpression) {
                let optionText = String(trimmed[match.upperBound...])
                    .trimmingCharacters(in: .init(charactersIn: "`"))
                currentOptions.append(QuizOption(text: optionText, isCorrect: true))
                continue
            }

            // Wrong answer: - [ ]
            if let match = trimmed.range(of: #"^- \[ \] "#, options: .regularExpression) {
                let optionText = String(trimmed[match.upperBound...])
                    .trimmingCharacters(in: .init(charactersIn: "`"))
                currentOptions.append(QuizOption(text: optionText, isCorrect: false))
                continue
            }

            // Explanation: > blockquote
            if trimmed.hasPrefix("> ") {
                let explanationLine = String(trimmed.dropFirst(2))
                if currentExplanation != nil {
                    currentExplanation! += " " + explanationLine
                } else {
                    currentExplanation = explanationLine
                }
                continue
            }
        }

        // Flush last question
        flushQuestion()

        return questions
    }
}
