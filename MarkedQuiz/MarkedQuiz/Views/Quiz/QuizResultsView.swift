import SwiftUI

struct QuizResultsView: View {
    let result: QuizResult
    let onDone: () -> Void
    let onRetry: () -> Void

    var scoreColor: Color {
        if result.percentage >= 80 { return CRT.greenAccent }
        if result.percentage >= 50 { return CRT.amber }
        return CRT.redAccent
    }

    var gradeLabel: String {
        if result.percentage >= 90 { return "EXCELLENT" }
        if result.percentage >= 80 { return "GREAT" }
        if result.percentage >= 70 { return "GOOD" }
        if result.percentage >= 50 { return "PASSING" }
        return "NEEDS WORK"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Score header
                VStack(spacing: 12) {
                    Text(gradeLabel)
                        .font(CRT.monoBold(24))
                        .foregroundStyle(scoreColor)
                        .crtGlow(color: scoreColor, radius: 8)

                    Text("\(result.score)/\(result.total)")
                        .font(CRT.monoBold(48))
                        .foregroundStyle(scoreColor)
                        .crtGlow(color: scoreColor, radius: 6)

                    Text(String(format: "%.0f%%", result.percentage))
                        .font(CRT.monoText(18))
                        .foregroundStyle(scoreColor.opacity(0.8))

                    // XP earned
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(CRT.amber)
                        Text("+\(result.xpEarned) XP")
                            .font(CRT.monoBold(16))
                            .foregroundStyle(CRT.amber)
                    }
                    .crtGlow(color: CRT.amber)
                }
                .padding(.top, 20)

                CRTSeparator()
                    .padding(.horizontal, 20)

                // Results breakdown
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESULTS BREAKDOWN")
                        .font(CRT.monoBold(12))
                        .foregroundStyle(CRT.textDim)
                        .padding(.horizontal, 20)

                    ForEach(result.results) { answerResult in
                        answerResultRow(answerResult)
                    }
                }

                CRTSeparator()
                    .padding(.horizontal, 20)

                // Action buttons
                HStack(spacing: 16) {
                    CRTSecondaryButton(title: "RETRY", icon: "arrow.clockwise", color: CRT.amber) {
                        onRetry()
                    }

                    CRTButton(title: "DONE", icon: "checkmark", color: CRT.greenAccent) {
                        onDone()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .background(CRT.bgDeep)
    }

    private func answerResultRow(_ answer: AnswerResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(answer.isCorrect ? CRT.greenAccent : CRT.redAccent)
                    .font(.system(size: 18))

                VStack(alignment: .leading, spacing: 4) {
                    Text(answer.question)
                        .font(CRT.monoText(13))
                        .foregroundStyle(CRT.orangeBright)
                        .lineLimit(3)

                    if !answer.isCorrect {
                        HStack(spacing: 4) {
                            Text("Your answer:")
                                .font(CRT.monoText(11))
                                .foregroundStyle(CRT.textDim)
                            Text(answer.userAnswer.isEmpty ? "(no answer)" : answer.userAnswer)
                                .font(CRT.monoText(11))
                                .foregroundStyle(CRT.redAccent)
                        }

                        HStack(spacing: 4) {
                            Text("Correct:")
                                .font(CRT.monoText(11))
                                .foregroundStyle(CRT.textDim)
                            Text(answer.correctAnswer)
                                .font(CRT.monoText(11))
                                .foregroundStyle(CRT.greenAccent)
                        }
                    }

                    Text(answer.explanation)
                        .font(CRT.monoText(11))
                        .foregroundStyle(CRT.textDim)
                        .lineSpacing(2)
                }
            }
        }
        .padding(12)
        .background(answer.isCorrect ? CRT.greenAccent.opacity(0.05) : CRT.redAccent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    (answer.isCorrect ? CRT.greenAccent : CRT.redAccent).opacity(0.2),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, 20)
    }
}
