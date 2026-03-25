import SwiftUI

// MARK: - Today's Habits Widget (live data)

struct HabitsWidget: View {
    @Environment(AuthService.self) private var auth
    @Environment(HabitsService.self) private var habitsService

    private let habitColors: [Color] = [
        Color(hex: 0x5B9BD5), Color(hex: 0x9B7DD4),
        Color(hex: 0x4CAF7D), Molten.Accent.primary,
        Molten.Accent.warm, Color(hex: 0x2DD4A0),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Today's Habits")
                    .font(.custom("Georgia", size: 16).weight(.semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if let maxStreak = maxStreak, maxStreak > 0 {
                    Text("\u{1F525} \(maxStreak)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Molten.Accent.warm)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Molten.Accent.warm.opacity(0.12))
                                .overlay(Capsule().stroke(Molten.Accent.warm.opacity(0.2), lineWidth: 1))
                        )
                }
            }
            .padding(.bottom, 10)

            // Progress bar
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 3)
                        .frame(width: 34, height: 34)
                    Circle()
                        .trim(from: 0, to: completionFraction)
                        .stroke(Color(hex: 0x4CAF7D), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: completionFraction)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(doneCount) of \(habitsService.habits.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Molten.Text.primary)
                    Text("habits complete")
                        .font(.system(size: 9))
                        .foregroundStyle(Molten.Text.tertiary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.04))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Molten.Card.border, lineWidth: 1))
            )
            .padding(.bottom, 10)

            // Habit rows
            if habitsService.isLoading {
                ProgressView()
                    .tint(Molten.Accent.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if habitsService.habits.isEmpty {
                Text("No habits yet")
                    .font(.system(size: 12))
                    .foregroundStyle(Molten.Text.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(habitsService.habits.enumerated()), id: \.element.id) { idx, habit in
                        let done = habitsService.isCompleted(habit, on: Date())
                        let streak = habitsService.streak(for: habit)
                        let color = habitColors[idx % habitColors.count]

                        Button(action: {
                            Task {
                                await habitsService.toggleHabit(habit, on: Date(), token: auth.accessToken)
                            }
                        }) {
                            HStack(spacing: 7) {
                                ZStack {
                                    Circle()
                                        .fill(done ? Color(hex: 0x4CAF7D) : Color.clear)
                                        .frame(width: 18, height: 18)
                                        .overlay(
                                            Circle().stroke(
                                                done ? Color(hex: 0x4CAF7D) : Color.white.opacity(0.25),
                                                lineWidth: 1.5
                                            )
                                        )
                                        .shadow(color: done ? Color(hex: 0x4CAF7D).opacity(0.4) : .clear, radius: 3)
                                    if done {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }

                                Text(habit.title)
                                    .font(.system(size: 11))
                                    .foregroundStyle(done ? Molten.Text.primary : Molten.Text.secondary)
                                    .fontWeight(done ? .medium : .regular)
                                    .lineLimit(1)

                                Spacer()

                                if streak > 0 {
                                    Text("\(streak)d")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(Molten.Text.tertiary)
                                }

                                Circle()
                                    .fill(color)
                                    .frame(width: 5, height: 5)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 10)
            }

            // View History
            Button(action: {}) {
                Text("VIEW HISTORY")
                    .font(.system(size: 9, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(Molten.Text.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Molten.Card.border, lineWidth: 1)
                    )
            }
        }
        .glassCard(radius: Molten.Radius.md, padding: 14)
        .onAppear {
            guard auth.isLoggedIn else { return }
            Task { await habitsService.fetchAll(token: auth.accessToken) }
        }
    }

    private var doneCount: Int {
        habitsService.completedCount(on: Date())
    }

    private var completionFraction: CGFloat {
        guard !habitsService.habits.isEmpty else { return 0 }
        return CGFloat(doneCount) / CGFloat(habitsService.habits.count)
    }

    private var maxStreak: Int? {
        habitsService.streaks.values.max()
    }
}
