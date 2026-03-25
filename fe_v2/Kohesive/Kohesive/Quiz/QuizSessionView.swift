import SwiftUI

/// Full-screen quiz taking session — one question at a time, multiple choice
struct QuizSessionView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    let quiz: Quiz
    @State private var currentIndex = 0
    @State private var selectedAnswer: Int?
    @State private var hasAnswered = false
    @State private var correctCount = 0
    @State private var answers: [Int: Int] = [:]   // questionIndex → selectedOption
    @State private var showResults = false

    private var question: QuizQuestion { quiz.questions[currentIndex] }
    private var isLast: Bool { currentIndex == quiz.questions.count - 1 }
    private var progress: CGFloat { CGFloat(currentIndex + 1) / CGFloat(quiz.questions.count) }

    var body: some View {
        ZStack {
            BlobBackground()

            if showResults {
                QuizResultsCard(
                    quiz: quiz,
                    correctCount: correctCount,
                    answers: answers,
                    onDone: { dismiss() }
                )
            } else {
                VStack(spacing: 0) {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Molten.Text.tertiary)
                        }
                        Spacer()
                        Text("\(currentIndex + 1) / \(quiz.questions.count)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Molten.Text.secondary)
                            .monospacedDigit()
                        Spacer()
                        // Spacer to balance the X button
                        Color.clear.frame(width: 16, height: 16)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 4)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Molten.Accent.primary, Molten.Accent.warm],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.easeOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Question text
                            Text(question.text)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Molten.Text.primary)
                                .lineSpacing(4)
                                .padding(.bottom, 4)

                            // Options
                            ForEach(Array(question.options.enumerated()), id: \.element.id) { idx, option in
                                OptionRow(
                                    label: optionLabel(idx),
                                    text: option.text,
                                    state: optionState(idx),
                                    action: { selectAnswer(idx) }
                                )
                            }

                            // Explanation (shown after answering)
                            if hasAnswered, let explanation = question.explanation {
                                HStack(spacing: 10) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Molten.Accent.warm)
                                    Text(explanation)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Molten.Text.secondary)
                                        .lineSpacing(3)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(Molten.Accent.warm.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Molten.Accent.warm.opacity(0.15), lineWidth: 1)
                                        )
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 120)
                    }

                    Spacer()

                    // Next / See Results button
                    if hasAnswered {
                        Button(action: advance) {
                            Text(isLast ? "See Results" : "Next")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Molten.Text.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule().fill(Molten.Accent.primary)
                                )
                                .shadow(color: Molten.Shadow.fab, radius: 10, y: 4)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 30)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasAnswered)
        .animation(.easeInOut(duration: 0.3), value: showResults)
    }

    // MARK: - Actions

    private func selectAnswer(_ idx: Int) {
        guard !hasAnswered else { return }
        selectedAnswer = idx
        hasAnswered = true
        answers[currentIndex] = idx
        if question.options[idx].isCorrect {
            correctCount += 1
        }
    }

    private func advance() {
        if isLast {
            // Record result to backend
            Task {
                await recordResult()
            }
            withAnimation { showResults = true }
        } else {
            currentIndex += 1
            selectedAnswer = nil
            hasAnswered = false
        }
    }

    private func recordResult() async {
        guard let token = auth.accessToken,
              let url = URL(string: "https://markedquiz.onrender.com/api/quiz-stats") else { return }

        let body: [String: Any] = [
            "quiz_name": quiz.title,
            "score": correctCount,
            "total_questions": quiz.questions.count,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Helpers

    private func optionLabel(_ idx: Int) -> String {
        ["A", "B", "C", "D", "E", "F"][min(idx, 5)]
    }

    enum OptionState {
        case idle, selected, correct, wrong
    }

    private func optionState(_ idx: Int) -> OptionState {
        guard hasAnswered else {
            return .idle
        }
        let option = question.options[idx]
        if option.isCorrect { return .correct }
        if idx == selectedAnswer { return .wrong }
        return .idle
    }
}

// MARK: - Option Row

private struct OptionRow: View {
    let label: String
    let text: String
    let state: QuizSessionView.OptionState
    let action: () -> Void

    private var borderColor: Color {
        switch state {
        case .idle: Molten.Card.border
        case .selected: Molten.Accent.primary
        case .correct: Color(hex: 0x4CAF7D)
        case .wrong: Color(hex: 0xF87171)
        }
    }

    private var bgColor: Color {
        switch state {
        case .idle: Molten.Card.bg
        case .selected: Molten.Accent.primary.opacity(0.12)
        case .correct: Color(hex: 0x4CAF7D).opacity(0.12)
        case .wrong: Color(hex: 0xF87171).opacity(0.12)
        }
    }

    private var labelColor: Color {
        switch state {
        case .idle: Molten.Text.tertiary
        case .selected: Molten.Accent.primary
        case .correct: Color(hex: 0x4CAF7D)
        case .wrong: Color(hex: 0xF87171)
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(labelColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(bgColor)
                            .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
                    )

                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(Molten.Text.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if state == .correct {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0x4CAF7D))
                }
                if state == .wrong {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: 0xF87171))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Molten.Radius.xl)
                    .fill(bgColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: Molten.Radius.xl)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
            .shadow(color: Molten.Shadow.deep.opacity(0.3), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(state != .idle)
        .animation(.easeOut(duration: 0.25), value: state)
    }
}

// MARK: - Results Card

private struct QuizResultsCard: View {
    let quiz: Quiz
    let correctCount: Int
    let answers: [Int: Int]
    let onDone: () -> Void

    private var percentage: Int {
        guard quiz.questionCount > 0 else { return 0 }
        return Int(Double(correctCount) / Double(quiz.questionCount) * 100)
    }

    private var gradeColor: Color {
        if percentage >= 70 { return Color(hex: 0x4CAF7D) }
        if percentage >= 40 { return Molten.Accent.warm }
        return Color(hex: 0xF87171)
    }

    private var gradeMessage: String {
        if percentage >= 90 { return "Excellent!" }
        if percentage >= 70 { return "Great job!" }
        if percentage >= 40 { return "Not bad!" }
        return "Keep studying!"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Score
                VStack(spacing: 8) {
                    Text("\(correctCount)/\(quiz.questionCount)")
                        .font(.custom("Georgia", size: 48).weight(.regular))
                        .foregroundStyle(gradeColor)

                    Text(gradeMessage)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Molten.Text.primary)

                    // Percentage bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 8)
                            Capsule()
                                .fill(gradeColor)
                                .frame(width: geo.size.width * CGFloat(percentage) / 100, height: 8)
                        }
                    }
                    .frame(height: 8)
                    .padding(.horizontal, 40)
                    .padding(.top, 4)
                }
                .glassCard(radius: Molten.Radius.xl, padding: 24)

                // Question breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("BREAKDOWN")
                        .font(.moltenSmall())
                        .tracking(1.5)
                        .foregroundStyle(Molten.Text.tertiary)
                        .padding(.bottom, 4)

                    ForEach(0..<quiz.questions.count, id: \.self) { i in
                        let q = quiz.questions[i]
                        let selected = answers[i]
                        let isCorrect = selected != nil && q.options[selected!].isCorrect

                        HStack(spacing: 10) {
                            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(isCorrect ? Color(hex: 0x4CAF7D) : Color(hex: 0xF87171))

                            Text(q.text)
                                .font(.system(size: 13))
                                .foregroundStyle(Molten.Text.secondary)
                                .lineLimit(2)

                            Spacer()
                        }
                        .padding(.vertical, 4)

                        if !isCorrect, let correctIdx = q.correctIndex {
                            Text("Correct: \(q.options[correctIdx].text)")
                                .font(.system(size: 11))
                                .foregroundStyle(Color(hex: 0x4CAF7D).opacity(0.7))
                                .padding(.leading, 24)
                                .padding(.bottom, 4)
                        }
                    }
                }
                .glassCard(radius: Molten.Radius.xl, padding: 18)

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Molten.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Capsule().fill(Molten.Accent.primary))
                        .shadow(color: Molten.Shadow.fab, radius: 10, y: 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 40)
        }
    }
}
