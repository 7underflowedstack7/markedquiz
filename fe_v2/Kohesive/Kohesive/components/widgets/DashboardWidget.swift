import SwiftUI

// MARK: - Dashboard Widget (live data)

struct DashboardWidget: View {
    @Environment(AuthService.self) private var auth
    @Environment(FileService.self) private var fileService
    @Environment(QuizStatsService.self) private var quizStats
    @Environment(HabitsService.self) private var habitsService
    @Environment(LevelService.self) private var levelService

    @State private var serverHealthy = true
    @State private var showGoalEditor = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Dashboard")
                    .font(.custom("Georgia", size: 16).weight(.semibold))
                    .foregroundStyle(Molten.Text.primary)
                Spacer()
                Button(action: { Task { await refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Molten.Text.secondary)
                }
            }
            .padding(.bottom, 12)

            // Stat grid — 2x2
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                StatTile(value: "\(fileService.fileCount)", label: "Files", color: Molten.Accent.warm, icon: "chart.line.uptrend.xyaxis")
                StatTile(value: "\(fileService.noteCount)", label: "Notes", color: Molten.Accent.primary, icon: "doc.text")
                StatTile(value: "\(maxStreak)", label: "Streak", color: Color(hex: 0x4CAF7D), icon: "flame.fill")
                StatTile(value: avgScoreText, label: "Avg Score", color: Molten.Accent.warm, icon: "star")
            }
            .padding(.bottom, 14)

            // Level ring + XP progress
            LevelRingView(
                level: levelService.level,
                xpInLevel: levelService.xpInCurrentLevel,
                xpForNext: levelService.xpForNextLevel,
                totalXP: levelService.totalXP
            )
            .padding(.bottom, 14)

            // Goal card
            GoalCardView(
                goalText: levelService.goalText,
                goalTarget: levelService.goalTarget,
                goalCurrent: levelService.goalCurrent,
                goalType: levelService.goalType,
                progress: levelService.goalProgress,
                onEdit: { showGoalEditor = true }
            )
            .padding(.bottom, 10)

            // Status bar
            HStack(spacing: 10) {
                HStack(spacing: 3) {
                    Circle().fill(serverHealthy ? Color(hex: 0x4CAF7D) : Color.red).frame(width: 4, height: 4)
                    Text("Server: \(serverHealthy ? "OK" : "Down")")
                        .font(.system(size: 9))
                        .foregroundStyle(Molten.Text.tertiary)
                }
                Spacer()
            }
        }
        .glassCard(radius: Molten.Radius.md, padding: 14)
        .onAppear {
            guard auth.isLoggedIn else { return }
            Task { await refresh() }
        }
        .sheet(isPresented: $showGoalEditor) {
            GoalEditorSheet()
                .environment(levelService)
                .environment(auth)
        }
    }

    private func refresh() async {
        await fileService.fetchFiles(token: auth.accessToken)
        await quizStats.fetchSummary(token: auth.accessToken)
        await levelService.fetchLevel(token: auth.accessToken)
        await checkHealth()
    }

    private func checkHealth() async {
        guard let url = URL(string: "https://markedquiz.onrender.com/api/health") else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            serverHealthy = (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            serverHealthy = false
        }
    }

    private var maxStreak: Int {
        habitsService.streaks.values.max() ?? 0
    }

    private var avgScoreText: String {
        let avg = quizStats.averageScore
        return avg > 0 ? "\(Int(avg))%" : "\u{2014}"
    }
}

// MARK: - Level Ring View

struct LevelRingView: View {
    let level: Int
    let xpInLevel: Int
    let xpForNext: Int
    let totalXP: Int

    private var progress: Double {
        guard xpForNext > 0 else { return 0 }
        return Double(xpInLevel) / Double(xpForNext)
    }

    var body: some View {
        HStack(spacing: 14) {
            // XP Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Color(hex: 0x9B7DD4), Color(hex: 0x5B9BD5), Color(hex: 0x4CAF7D)],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: progress)

                VStack(spacing: 0) {
                    Text("\(level)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Molten.Text.primary)
                    Text("LVL")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(Molten.Text.tertiary)
                }
            }

            // XP details
            VStack(alignment: .leading, spacing: 6) {
                Text("EXPERIENCE")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Molten.Text.tertiary)

                // XP bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0x9B7DD4), Color(hex: 0x5B9BD5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.easeOut(duration: 0.6), value: progress)
                    }
                }
                .frame(height: 6)

                HStack {
                    Text("\(xpInLevel) / \(xpForNext) XP")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: 0x9B7DD4))
                    Spacer()
                    Text("\(totalXP) total")
                        .font(.system(size: 9))
                        .foregroundStyle(Molten.Text.tertiary)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Molten.Card.border, lineWidth: 0.5))
        )
    }
}

// MARK: - Goal Card View

struct GoalCardView: View {
    let goalText: String?
    let goalTarget: Int?
    let goalCurrent: Int
    let goalType: String?
    let progress: Double
    let onEdit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("GOAL")
                    .font(.system(size: 8, weight: .medium))
                    .tracking(1)
                    .foregroundStyle(Molten.Text.tertiary)
                Spacer()
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10))
                        .foregroundStyle(Molten.Text.secondary)
                }
                .buttonStyle(.plain)
            }

            if let goalText, let goalTarget {
                HStack(spacing: 8) {
                    // Goal type icon
                    Image(systemName: iconForGoalType(goalType))
                        .font(.system(size: 12))
                        .foregroundStyle(Color(hex: 0x4CAF7D))
                        .frame(width: 24, height: 24)
                        .background(
                            Circle()
                                .fill(Color(hex: 0x4CAF7D).opacity(0.12))
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(goalText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Molten.Text.primary)
                            .lineLimit(2)

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: 0x4CAF7D))
                                    .frame(width: geo.size.width * progress, height: 4)
                                    .animation(.easeOut(duration: 0.5), value: progress)
                            }
                        }
                        .frame(height: 4)

                        Text("\(goalCurrent) / \(goalTarget)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Molten.Text.tertiary)
                    }
                }
            } else {
                Button(action: onEdit) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                        Text("Set a goal")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(Molten.Text.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Molten.Card.border, lineWidth: 0.5))
        )
    }

    private func iconForGoalType(_ type: String?) -> String {
        switch type {
        case "level": return "arrow.up.circle"
        case "xp": return "star.circle"
        case "streak": return "flame"
        default: return "target"
        }
    }
}

// MARK: - Goal Editor Sheet

struct GoalEditorSheet: View {
    @Environment(LevelService.self) private var levelService
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var goalText = ""
    @State private var goalTarget = ""
    @State private var goalCurrent = ""
    @State private var goalType = "custom"
    @State private var isSaving = false

    private let goalTypes = [
        ("custom", "Custom", "target"),
        ("level", "Reach Level", "arrow.up.circle"),
        ("xp", "Earn XP", "star.circle"),
        ("streak", "Streak Days", "flame"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Goal type picker
                    SettingsSection(title: "GOAL TYPE") {
                        HStack(spacing: 6) {
                            ForEach(goalTypes, id: \.0) { type in
                                let isActive = goalType == type.0
                                Button {
                                    goalType = type.0
                                    prefillForType(type.0)
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: type.2)
                                            .font(.system(size: 16))
                                            .foregroundStyle(isActive ? Color(hex: 0x4CAF7D) : Molten.Text.secondary)
                                        Text(type.1)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(isActive ? Molten.Text.primary : Molten.Text.tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isActive ? Color(hex: 0x4CAF7D).opacity(0.12) : Molten.Card.bg)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isActive ? Color(hex: 0x4CAF7D).opacity(0.3) : Molten.Card.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Goal details
                    SettingsSection(title: "DETAILS") {
                        VStack(spacing: 12) {
                            // Goal text
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Description")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Molten.Text.tertiary)
                                TextField("e.g., Pass all biology quizzes", text: $goalText)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Molten.Text.primary)
                                    .tint(Molten.Accent.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(Molten.Card.bg)
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Molten.Card.border, lineWidth: 1))
                                    )
                            }

                            HStack(spacing: 12) {
                                // Target
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Target")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Molten.Text.tertiary)
                                    TextField("500", text: $goalTarget)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundStyle(Molten.Text.primary)
                                        .keyboardType(.numberPad)
                                        .tint(Molten.Accent.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Molten.Card.bg)
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Molten.Card.border, lineWidth: 1))
                                        )
                                }

                                // Current progress
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Molten.Text.tertiary)
                                    TextField("0", text: $goalCurrent)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundStyle(Molten.Text.primary)
                                        .keyboardType(.numberPad)
                                        .tint(Molten.Accent.primary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(Molten.Card.bg)
                                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Molten.Card.border, lineWidth: 1))
                                        )
                                }
                            }
                        }
                    }

                    // Save
                    Button {
                        Task { await saveGoal() }
                    } label: {
                        HStack(spacing: 8) {
                            if isSaving {
                                ProgressView().tint(Molten.Base._950).scaleEffect(0.7)
                            }
                            Text("Save Goal")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(Molten.Base._950)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: 0x4CAF7D), Color(hex: 0x2DD4A0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                        .shadow(color: Color(hex: 0x4CAF7D).opacity(0.3), radius: 8, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(goalText.isEmpty || goalTarget.isEmpty || isSaving)
                    .opacity(goalText.isEmpty || goalTarget.isEmpty ? 0.5 : 1)

                    // Clear goal
                    if levelService.goalText != nil {
                        Button {
                            Task {
                                await levelService.updateGoal(
                                    text: nil, target: nil, current: nil, type: nil,
                                    token: auth.accessToken
                                )
                                dismiss()
                            }
                        } label: {
                            Text("Clear Goal")
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .navigationTitle("Set Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Molten.Text.secondary)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Molten.BG.deep)
        .preferredColorScheme(.dark)
        .onAppear {
            // Pre-fill with existing goal
            goalText = levelService.goalText ?? ""
            goalTarget = levelService.goalTarget.map { "\($0)" } ?? ""
            goalCurrent = "\(levelService.goalCurrent)"
            goalType = levelService.goalType ?? "custom"
        }
    }

    private func saveGoal() async {
        isSaving = true
        let target = Int(goalTarget)
        let current = Int(goalCurrent) ?? 0
        await levelService.updateGoal(
            text: goalText,
            target: target,
            current: current,
            type: goalType,
            token: auth.accessToken
        )
        isSaving = false
        dismiss()
    }

    private func prefillForType(_ type: String) {
        switch type {
        case "level":
            if goalText.isEmpty || goalText.hasPrefix("Reach") || goalText.hasPrefix("Earn") || goalText.hasPrefix("Maintain") {
                goalText = "Reach Level \(levelService.level + 5)"
                goalTarget = "\(levelService.level + 5)"
                goalCurrent = "\(levelService.level)"
            }
        case "xp":
            if goalText.isEmpty || goalText.hasPrefix("Reach") || goalText.hasPrefix("Earn") || goalText.hasPrefix("Maintain") {
                goalText = "Earn 1000 XP"
                goalTarget = "1000"
                goalCurrent = "\(levelService.totalXP)"
            }
        case "streak":
            if goalText.isEmpty || goalText.hasPrefix("Reach") || goalText.hasPrefix("Earn") || goalText.hasPrefix("Maintain") {
                goalText = "Maintain a 14-day streak"
                goalTarget = "14"
                goalCurrent = "0"
            }
        default:
            break
        }
    }
}

// MARK: - Stat Tile

struct StatTile: View {
    let value: String
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(Molten.Text.tertiary)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(color.opacity(0.5))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Molten.Card.border, lineWidth: 0.5))
        )
    }
}
