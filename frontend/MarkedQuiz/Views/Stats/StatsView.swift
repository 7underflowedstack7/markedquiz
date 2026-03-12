import SwiftUI

struct StatsView: View {
    @State private var viewModel = StatsViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                CRT.bgDeep.ignoresSafeArea()

                if viewModel.isLoading && viewModel.stats == nil {
                    CRTLoadingView(message: "Loading stats")
                } else if let error = viewModel.errorMessage, viewModel.stats == nil {
                    CRTErrorView(message: error) {
                        await viewModel.loadAll()
                    }
                } else if let stats = viewModel.stats {
                    statsContent(stats)
                } else {
                    CRTEmptyView(
                        icon: "chart.bar",
                        title: "NO DATA",
                        message: "Complete some quizzes to see your stats."
                    )
                }

                ScanlinesOverlay()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("STATS")
                        .font(CRT.monoBold(16))
                        .foregroundStyle(CRT.orangeBright)
                        .crtGlow()
                }
            }
            .toolbarBackground(CRT.bgPanel, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.loadAll()
            }
            .refreshable {
                await viewModel.loadAll()
            }
        }
    }

    private func statsContent(_ stats: StatsResponse) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Level & XP card
                levelCard(stats)

                // Stats grid
                statsGrid(stats)

                // Score history chart
                if !viewModel.scoreHistory.isEmpty {
                    scoreHistorySection
                }

                // Subject breakdown
                if !viewModel.subjectStats.isEmpty {
                    subjectSection
                }

                // Recent attempts
                if !viewModel.attempts.isEmpty {
                    recentAttemptsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 20)
        }
    }

    private func levelCard(_ stats: StatsResponse) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LEVEL \(stats.level)")
                        .font(CRT.monoBold(28))
                        .foregroundStyle(CRT.amber)
                        .crtGlow(color: CRT.amber, radius: 6)

                    Text("\(stats.totalXp) XP TOTAL")
                        .font(CRT.monoText(12))
                        .foregroundStyle(CRT.orangeDim)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(CRT.bgLine, lineWidth: 6)
                        .frame(width: 64, height: 64)

                    let progress = stats.xpForNextLevel > 0
                        ? Double(stats.xpProgressInLevel) / Double(stats.xpForNextLevel)
                        : 0

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(CRT.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: CRT.amber.opacity(0.3), radius: 4)

                    Text("\(Int(progress * 100))%")
                        .font(CRT.monoBold(12))
                        .foregroundStyle(CRT.amber)
                }
            }

            // XP progress bar
            VStack(spacing: 4) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(CRT.bgLine)
                            .frame(height: 6)

                        let progress = stats.xpForNextLevel > 0
                            ? CGFloat(stats.xpProgressInLevel) / CGFloat(stats.xpForNextLevel)
                            : 0

                        RoundedRectangle(cornerRadius: 3)
                            .fill(CRT.amber)
                            .frame(width: geo.size.width * progress, height: 6)
                            .shadow(color: CRT.amber.opacity(0.4), radius: 3)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(stats.xpProgressInLevel) XP")
                        .font(CRT.monoText(10))
                        .foregroundStyle(CRT.textDim)
                    Spacer()
                    Text("\(stats.xpForNextLevel) XP")
                        .font(CRT.monoText(10))
                        .foregroundStyle(CRT.textDim)
                }
            }
        }
        .padding(16)
        .crtPanel()
    }

    private func statsGrid(_ stats: StatsResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "flame.fill", label: "STREAK", value: "\(stats.streakDays) days", color: CRT.orangeHot)
            statCard(icon: "trophy.fill", label: "BEST STREAK", value: "\(stats.bestStreak) days", color: CRT.amber)
            statCard(icon: "checkmark.circle.fill", label: "QUIZZES", value: "\(stats.quizzesCompleted)", color: CRT.greenAccent)
            statCard(icon: "percent", label: "AVG SCORE", value: String(format: "%.0f%%", stats.averageScore), color: CRT.cyanAccent)
        }
    }

    private func statCard(icon: String, label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .crtGlow(color: color)

            Text(value)
                .font(CRT.monoBold(18))
                .foregroundStyle(color)

            Text(label)
                .font(CRT.monoText(10))
                .foregroundStyle(CRT.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .crtPanel()
    }

    private var scoreHistorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SCORE HISTORY")
                .font(CRT.monoBold(12))
                .foregroundStyle(CRT.textDim)

            // Simple bar chart
            GeometryReader { geo in
                let barWidth = max(4, (geo.size.width - CGFloat(viewModel.scoreHistory.count) * 3) / CGFloat(viewModel.scoreHistory.count))

                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(viewModel.scoreHistory) { item in
                        VStack(spacing: 2) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(barColor(for: item.score))
                                .frame(width: barWidth, height: max(4, geo.size.height * 0.8 * item.score / 100))
                                .shadow(color: barColor(for: item.score).opacity(0.3), radius: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 80)
            .padding(.horizontal, 4)
            .crtPanel()
            .padding(.vertical, 4)
        }
    }

    private func barColor(for score: Double) -> Color {
        if score >= 80 { return CRT.greenAccent }
        if score >= 50 { return CRT.amber }
        return CRT.redAccent
    }

    private var subjectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SUBJECTS")
                .font(CRT.monoBold(12))
                .foregroundStyle(CRT.textDim)

            ForEach(viewModel.subjectStats) { subject in
                HStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(CRT.orangeDim)
                        .font(.system(size: 18))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(subject.documentTitle)
                            .font(CRT.monoBold(13))
                            .foregroundStyle(CRT.orangeBright)
                            .lineLimit(1)

                        HStack(spacing: 10) {
                            Text("\(subject.attempts) attempts")
                            Text("Best: \(String(format: "%.0f%%", subject.bestScore))")
                            Text("\(subject.totalXp) XP")
                        }
                        .font(CRT.monoText(10))
                        .foregroundStyle(CRT.textDim)
                    }

                    Spacer()

                    Text(String(format: "%.0f%%", subject.averageScore))
                        .font(CRT.monoBold(16))
                        .foregroundStyle(barColor(for: subject.averageScore))
                }
                .padding(12)
                .crtPanel()
            }
        }
    }

    private var recentAttemptsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENT ATTEMPTS")
                .font(CRT.monoBold(12))
                .foregroundStyle(CRT.textDim)

            ForEach(viewModel.attempts.prefix(5)) { attempt in
                HStack(spacing: 12) {
                    Image(systemName: attempt.percentage >= 50 ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(attempt.percentage >= 50 ? CRT.greenAccent : CRT.redAccent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attempt.documentTitle)
                            .font(CRT.monoText(13))
                            .foregroundStyle(CRT.orangeBright)
                            .lineLimit(1)

                        Text(attempt.completedAt.prefix(10))
                            .font(CRT.monoText(10))
                            .foregroundStyle(CRT.textDim)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(attempt.score)/\(attempt.total)")
                            .font(CRT.monoBold(14))
                            .foregroundStyle(barColor(for: attempt.percentage))

                        Text("+\(attempt.xpEarned) XP")
                            .font(CRT.monoText(10))
                            .foregroundStyle(CRT.amber)
                    }
                }
                .padding(12)
                .crtPanel()
            }
        }
    }
}
