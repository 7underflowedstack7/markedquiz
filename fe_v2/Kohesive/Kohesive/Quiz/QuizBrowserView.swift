import SwiftUI

/// Quizzes landing — stats card, quiz list grouped by folder, launch quiz sessions
struct QuizBrowserView: View {
    @Environment(AuthService.self) private var auth
    @Environment(QuizStatsService.self) private var quizStats
    @State private var quizService = QuizService()
    @State private var selectedQuiz: Quiz?
    @State private var appeared = false

    var body: some View {
        ZStack {
            BlobBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {

                    // ── Stats Card ──
                    QuizStatsCard()
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)

                    // ── Quiz List ──
                    if quizService.isLoading {
                        ProgressView()
                            .tint(Molten.Accent.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if quizService.quizzes.isEmpty {
                        EmptyQuizState()
                            .opacity(appeared ? 1 : 0)
                    } else {
                        // Grouped by folder
                        ForEach(quizService.quizzesByFolder, id: \.folder) { group in
                            SectionLabel(text: folderDisplayName(group.folder))

                            ForEach(group.quizzes) { quiz in
                                QuizCard(quiz: quiz) {
                                    selectedQuiz = quiz
                                }
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 16)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Quizzes")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            appeared = true
            guard auth.isLoggedIn else { return }
            Task {
                await quizService.fetchQuizzes(token: auth.accessToken)
                await quizStats.fetchSummary(token: auth.accessToken)
            }
        }
        .fullScreenCover(item: $selectedQuiz) { quiz in
            QuizSessionView(quiz: quiz)
        }
    }

    private func folderDisplayName(_ folder: String) -> String {
        // "quiz/python" → "Python"
        let parts = folder.split(separator: "/")
        if parts.count > 1 {
            return parts.last.map { String($0).capitalized } ?? folder
        }
        return folder.capitalized
    }
}

// MARK: - Stats Card

private struct QuizStatsCard: View {
    @Environment(QuizStatsService.self) private var stats

    var body: some View {
        HStack(spacing: 0) {
            StatBlock(
                value: stats.totalCompleted > 0 ? "\(Int(stats.averageScore))%" : "—",
                label: "AVG SCORE",
                color: Molten.Accent.warm
            )
            StatBlock(
                value: "\(stats.totalCompleted)",
                label: "COMPLETED",
                color: Molten.Accent.primary
            )
            StatBlock(
                value: stats.bestScore > 0 ? "\(Int(stats.bestScore))%" : "—",
                label: "BEST",
                color: Color(hex: 0x4CAF7D)
            )
        }
        .glassCard(radius: Molten.Radius.xl, padding: 16)
    }
}

private struct StatBlock: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.custom("Georgia", size: 24).weight(.regular))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .tracking(1)
                .foregroundStyle(Molten.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Quiz Card

private struct QuizCard: View {
    let quiz: Quiz
    let onStart: () -> Void

    private var difficultyColor: Color {
        switch quiz.difficulty {
        case "beginner": Color(hex: 0x4CAF7D)
        case "intermediate": Molten.Accent.warm
        case "advanced": Molten.Accent.primary
        default: Molten.Text.tertiary
        }
    }

    var body: some View {
        Button(action: onStart) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(quiz.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Molten.Text.primary)
                        .lineLimit(2)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Molten.Accent.primary)
                }

                HStack(spacing: 8) {
                    // Question count
                    Text("\(quiz.questionCount)q")
                        .glassPill()

                    // Difficulty
                    Text(quiz.difficulty.capitalized)
                        .font(.moltenSmall())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(difficultyColor.opacity(0.12))
                                .overlay(Capsule().stroke(difficultyColor.opacity(0.2), lineWidth: 1))
                        )
                        .foregroundStyle(difficultyColor)

                    // Tags
                    ForEach(quiz.tags.prefix(2), id: \.self) { tag in
                        Text(tag)
                            .glassPill()
                    }
                }
            }
            .glassCard(radius: Molten.Radius.xl, padding: 16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

private struct EmptyQuizState: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.folder")
                .font(.system(size: 32))
                .foregroundStyle(Molten.Text.tertiary)
            Text("No quizzes found")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Molten.Text.primary)
            Text("Upload .md quiz files to a folder starting with \"quiz/\" to get started.")
                .font(.moltenBody(13))
                .foregroundStyle(Molten.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
