import SwiftUI

/// Full habits management — streak card, progress ring, habit list with CRUD, weekly grid
struct HabitsFullView: View {
    @Environment(AuthService.self) private var auth
    @Environment(HabitsService.self) private var habitsService

    @State private var showCreate = false
    @State private var editingHabit: HabitItem?
    @State private var appeared = false
    @State private var weekExpanded = false

    private let habitColors: [Color] = [
        Color(hex: 0x5B9BD5), Color(hex: 0x9B7DD4),
        Color(hex: 0x4CAF7D), Molten.Accent.primary,
        Molten.Accent.warm, Color(hex: 0x2DD4A0),
    ]

    var body: some View {
        ZStack {
            BlobBackground()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {

                // ── Streak Card (c6-streak-block style) ──
                StreakCard(streak: maxStreak)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                // ── Progress Card (w2-hab-progress style) ──
                ProgressCard(
                    done: doneCount,
                    total: habitsService.habits.count
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // ── Weekly Activity Card (c7-stats style) ──
                WeeklyActivityCard(
                    entries: habitsService.entries,
                    habits: habitsService.habits,
                    habitCount: habitsService.habits.count,
                    doneToday: doneCount,
                    bestStreak: maxStreak,
                    isExpanded: $weekExpanded
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // ── Action Row ──
                HStack(spacing: 10) {
                    Button(action: { showCreate = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Molten.Accent.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Molten.Accent.primary.opacity(0.12))
                                )
                            Text("New Habit")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Molten.Text.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCardSmall()
                    }
                    .buttonStyle(.plain)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)

                // ── Habits List (w2-hab-row style) ──
                SectionLabel(text: "Today's Habits")

                if habitsService.isLoading {
                    ProgressView()
                        .tint(Molten.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                } else if habitsService.habits.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 32))
                            .foregroundStyle(Molten.Text.tertiary)
                        Text("No habits yet. Tap New Habit to start tracking.")
                            .font(.moltenBody(14))
                            .foregroundStyle(Molten.Text.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
                } else {
                    ForEach(Array(habitsService.habits.enumerated()), id: \.element.id) { idx, habit in
                        HabitRow(
                            habit: habit,
                            done: habitsService.isCompleted(habit, on: Date()),
                            streak: habitsService.streak(for: habit),
                            color: habitColors[idx % habitColors.count],
                            onToggle: {
                                Task { await habitsService.toggleHabit(habit, on: Date(), token: auth.accessToken) }
                            },
                            onEdit: { editingHabit = habit },
                            onDelete: {
                                Task { await habitsService.deleteHabit(habit, token: auth.accessToken) }
                            }
                        )
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(
                            .easeOut(duration: 0.45).delay(0.1 + Double(idx) * 0.04),
                            value: appeared
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        } // ZStack
        .navigationTitle("Habits")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            appeared = true
            guard auth.isLoggedIn else { return }
            Task { await habitsService.fetchAll(token: auth.accessToken) }
        }
        .sheet(isPresented: $showCreate) {
            CreateHabitSheet { title, description, icon, color in
                Task {
                    await habitsService.createHabit(
                        title: title, description: description,
                        icon: icon, color: color, token: auth.accessToken
                    )
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .sheet(item: $editingHabit) { habit in
            EditHabitSheet(habit: habit) { title, description, icon, color in
                Task {
                    await habitsService.updateHabit(
                        habit, title: title, description: description,
                        icon: icon, color: color, token: auth.accessToken
                    )
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
    }

    private var doneCount: Int { habitsService.completedCount(on: Date()) }
    private var maxStreak: Int { habitsService.streaks.values.max() ?? 0 }
}

// MARK: - Streak Card (c6-streak-block)

private struct StreakCard: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 14) {
            Text("🔥")
                .font(.system(size: 32))

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streak)")
                    .font(.custom("Georgia", size: 36).weight(.regular))
                    .foregroundStyle(Molten.Accent.warm)
                Text("day streak")
                    .font(.system(size: 12))
                    .foregroundStyle(Molten.Text.tertiary)
                    .textCase(.uppercase)
                    .tracking(1)
            }

            Spacer()
        }
        .glassCard(radius: Molten.Radius.xl, padding: 20)
    }
}

// MARK: - Progress Card (w2-hab-progress)

private struct ProgressCard: View {
    let done: Int
    let total: Int

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(done) / CGFloat(total)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 5)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color(hex: 0x4CAF7D), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.6), value: fraction)

                Text("\(Int(fraction * 100))%")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Molten.Text.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(done) of \(total)")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Molten.Text.primary)
                Text("habits complete today")
                    .font(.system(size: 12))
                    .foregroundStyle(Molten.Text.tertiary)
            }

            Spacer()
        }
        .glassCard(radius: Molten.Radius.xl, padding: 18)
    }
}

// MARK: - Weekly Activity Card (c7-stats-card style)

private struct WeeklyActivityCard: View {
    let entries: [HabitEntry]
    let habits: [HabitItem]
    let habitCount: Int
    let doneToday: Int
    let bestStreak: Int
    @Binding var isExpanded: Bool

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let barMaxHeight: CGFloat = 48

    private var weeklyRate: Int {
        guard habitCount > 0 else { return 0 }
        var total = 0
        var done = 0
        for i in 0..<7 {
            let date = weekDate(offset: i)
            let count = completedOn(date)
            total += habitCount
            done += count
        }
        guard total > 0 else { return 0 }
        return Int(Double(done) / Double(total) * 100)
    }

    var body: some View {
        VStack(spacing: 0) {
            // ── Trigger card ──
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    isExpanded.toggle()
                }
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    HStack {
                        Text("This Week")
                            .font(.custom("Georgia", size: 22).weight(.regular))
                            .foregroundStyle(Molten.Text.primary)

                        Spacer()

                        // Calendar icon box (c7-stats-icon)
                        Image(systemName: "calendar")
                            .font(.system(size: 13))
                            .foregroundStyle(Molten.Text.tertiary)
                            .frame(width: 30, height: 30)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.04))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                                    )
                            )
                    }
                    .padding(.bottom, 16)

                    // Mini stat boxes (c7-mini-stat-box)
                    HStack(spacing: 10) {
                        MiniStatBox(value: "\(doneToday)/\(habitCount)", label: "Today", color: Molten.Accent.warm)
                        MiniStatBox(value: "\(bestStreak)d", label: "Streak", color: Molten.Accent.primary)
                        MiniStatBox(value: "\(weeklyRate)%", label: "Rate", color: Color(hex: 0x2DD4A0))
                    }
                    .padding(.bottom, 18)

                    // Bar chart label
                    Text("WEEKLY ACTIVITY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(Molten.Text.tertiary)
                        .padding(.bottom, 10)

                    // Bar chart (c7-bar-chart)
                    HStack(alignment: .bottom, spacing: 0) {
                        ForEach(0..<7, id: \.self) { i in
                            let date = weekDate(offset: i)
                            let count = completedOn(date)
                            let ratio = habitCount > 0 ? CGFloat(count) / CGFloat(habitCount) : 0
                            let isToday = Calendar.current.isDateInToday(date)

                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [Molten.Accent.primary, Molten.Accent.warm],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .opacity(ratio > 0 ? 0.82 : 0.12)
                                    .frame(width: 8, height: max(4, ratio * barMaxHeight))

                                Text(dayLabels[i])
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        isToday ? Molten.Accent.primary : Molten.Text.tertiary
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: barMaxHeight + 20, alignment: .bottom)

                    // Expand hint
                    HStack {
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Molten.Text.tertiary)
                        Text(isExpanded ? "Hide details" : "View all habits")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Molten.Text.tertiary)
                        Spacer()
                    }
                    .padding(.top, 14)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: Molten.Radius.xl)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: Molten.Radius.xl)
                                .fill(Molten.Card.bg)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Molten.Radius.xl)
                        .stroke(
                            isExpanded ? Molten.Accent.primary.opacity(0.25) : Molten.Card.border,
                            lineWidth: 1
                        )
                )
                .shadow(color: Molten.Shadow.deep, radius: 16, x: 0, y: 8)
                .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // ── Expanded detail panel ──
            if isExpanded {
                WeeklyDetailPanel(entries: entries, habits: habits, habitCount: habitCount)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .padding(.top, 10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: isExpanded)
    }

    // MARK: Helpers

    private func weekDate(offset: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: offset - mondayOffset, to: today)!
    }

    private func completedOn(_ date: Date) -> Int {
        let dateStr = Self.dateFmt.string(from: date)
        return entries.filter { $0.date == dateStr && $0.completed }.count
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Mini Stat Box (c7-mini-stat-box)

private struct MiniStatBox: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.custom("Georgia", size: 24).weight(.regular))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1)
                .foregroundStyle(Molten.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

// MARK: - Weekly Detail Panel (inline expand)

private struct WeeklyDetailPanel: View {
    let entries: [HabitEntry]
    let habits: [HabitItem]
    let habitCount: Int

    private let dayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let green = Color(hex: 0x4CAF7D)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<7, id: \.self) { i in
                let date = weekDate(offset: i)
                let isToday = Calendar.current.isDateInToday(date)
                let dateStr = Self.dateFmt.string(from: date)
                let dayNum = Calendar.current.component(.day, from: date)

                VStack(alignment: .leading, spacing: 8) {
                    // Day header
                    HStack(spacing: 8) {
                        Text("\(dayNum)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(isToday ? Molten.Accent.primary : Molten.Text.primary)
                            .frame(width: 28, alignment: .trailing)

                        Text(dayLabels[i])
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(isToday ? Molten.Accent.primary : Molten.Text.secondary)

                        if isToday {
                            Text("TODAY")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1)
                                .foregroundStyle(Molten.Accent.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule().fill(Molten.Accent.primary.opacity(0.12))
                                )
                        }

                        Spacer()

                        // Day completion count
                        let dayDone = completedOn(date)
                        if habitCount > 0 {
                            Text("\(dayDone)/\(habitCount)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(
                                    dayDone == habitCount && habitCount > 0
                                        ? green
                                        : Molten.Text.tertiary
                                )
                        }
                    }

                    // Habit rows for this day
                    if habits.isEmpty {
                        Text("No habits")
                            .font(.system(size: 12))
                            .foregroundStyle(Molten.Text.tertiary)
                            .padding(.leading, 36)
                    } else {
                        VStack(spacing: 4) {
                            ForEach(habits) { habit in
                                let done = entries.contains {
                                    $0.habitId == habit.id && $0.date == dateStr && $0.completed
                                }

                                HStack(spacing: 10) {
                                    // Check/miss indicator
                                    ZStack {
                                        Circle()
                                            .fill(done ? green : Color.clear)
                                            .frame(width: 18, height: 18)
                                            .overlay(
                                                Circle().stroke(
                                                    done ? green : Color.white.opacity(0.15),
                                                    lineWidth: 1.5
                                                )
                                            )
                                        if done {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }

                                    Text(habit.title)
                                        .font(.system(size: 12))
                                        .foregroundStyle(
                                            done ? Molten.Text.primary : Molten.Text.tertiary
                                        )
                                        .lineLimit(1)

                                    Spacer()
                                }
                                .padding(.leading, 36)
                            }
                        }
                    }
                }
                .padding(.vertical, 12)

                // Divider between days (not after last)
                if i < 6 {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 1)
                        .padding(.leading, 36)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Molten.Radius.md)
                .fill(Molten.Card.bg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Molten.Radius.md)
                .stroke(Molten.Card.border, lineWidth: 1)
        )
    }

    // MARK: Helpers

    private func weekDate(offset: Int) -> Date {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let mondayOffset = (weekday + 5) % 7
        return cal.date(byAdding: .day, value: offset - mondayOffset, to: today)!
    }

    private func completedOn(_ date: Date) -> Int {
        let dateStr = Self.dateFmt.string(from: date)
        return entries.filter { $0.date == dateStr && $0.completed }.count
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

// MARK: - Habit Row (w2-hab-row with context menu)

private struct HabitRow: View {
    let habit: HabitItem
    let done: Bool
    let streak: Int
    let color: Color
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Check circle
                ZStack {
                    Circle()
                        .fill(done ? Color(hex: 0x4CAF7D) : Color.clear)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(
                                done ? Color(hex: 0x4CAF7D) : Color.white.opacity(0.25),
                                lineWidth: 2
                            )
                        )
                        .shadow(color: done ? Color(hex: 0x4CAF7D).opacity(0.4) : .clear, radius: 4)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.title)
                        .font(.system(size: 14, weight: done ? .medium : .regular))
                        .foregroundStyle(done ? Molten.Text.primary : Molten.Text.secondary)
                    if !habit.description.isEmpty {
                        Text(habit.description)
                            .font(.system(size: 11))
                            .foregroundStyle(Molten.Text.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if streak > 0 {
                    HStack(spacing: 3) {
                        Text("\(streak)d")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Molten.Text.tertiary)
                        Text("🔥")
                            .font(.system(size: 10))
                    }
                }

                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            .glassCard(radius: Molten.Radius.xl, padding: 14)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Create Habit Sheet

private struct CreateHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedColor = "teal"
    @State private var selectedIcon = "flame.fill"

    let onCreate: (String, String, String, String) -> Void

    private let colorOptions: [(name: String, color: Color)] = [
        ("teal", Color(hex: 0x5B9BD5)),
        ("ochre", Molten.Accent.warm),
        ("lichen", Color(hex: 0x4CAF7D)),
        ("warm", Molten.Accent.primary),
        ("cool", Color(hex: 0x9B7DD4)),
    ]

    private let iconOptions = ["flame.fill", "book.fill", "dumbbell.fill", "pencil", "laptopcomputer", "figure.walk"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Habit")
                .font(.moltenTitle(22))
                .foregroundStyle(Molten.Text.primary)
                .padding(.top, 8)

            // Title
            VStack(alignment: .leading, spacing: 6) {
                Text("TITLE")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("e.g. Study 30min", text: $title)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            // Description
            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION (OPTIONAL)")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("Short description", text: $description)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            // Color picker
            VStack(alignment: .leading, spacing: 6) {
                Text("COLOR")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.name) { opt in
                        Circle()
                            .fill(opt.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: selectedColor == opt.name ? 2 : 0)
                            )
                            .onTapGesture { selectedColor = opt.name }
                    }
                }
            }

            // Icon picker
            VStack(alignment: .leading, spacing: 6) {
                Text("ICON")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon ? Molten.Accent.primary : Molten.Text.tertiary)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Molten.Accent.primary.opacity(0.15) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIcon == icon ? Molten.Accent.primary.opacity(0.3) : Molten.Card.border, lineWidth: 1)
                            )
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Spacer()

            // Create button
            Button {
                onCreate(title, description, selectedIcon, selectedColor)
                dismiss()
            } label: {
                Text("Create Habit")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Molten.Accent.primary)
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 8, y: 4)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(24)
    }
}

// MARK: - Edit Habit Sheet

private struct EditHabitSheet: View {
    @Environment(\.dismiss) private var dismiss
    let habit: HabitItem
    @State private var title: String
    @State private var description: String
    @State private var selectedIcon: String
    @State private var selectedColor: String

    let onSave: (String, String, String, String) -> Void

    init(habit: HabitItem, onSave: @escaping (String, String, String, String) -> Void) {
        self.habit = habit
        self.onSave = onSave
        _title = State(initialValue: habit.title)
        _description = State(initialValue: habit.description)
        _selectedIcon = State(initialValue: habit.icon)
        _selectedColor = State(initialValue: habit.color)
    }

    private let colorOptions: [(name: String, color: Color)] = [
        ("teal", Color(hex: 0x5B9BD5)),
        ("ochre", Molten.Accent.warm),
        ("lichen", Color(hex: 0x4CAF7D)),
        ("warm", Molten.Accent.primary),
        ("cool", Color(hex: 0x9B7DD4)),
    ]

    private let iconOptions = ["flame.fill", "book.fill", "dumbbell.fill", "pencil", "laptopcomputer", "figure.walk"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit Habit")
                .font(.moltenTitle(22))
                .foregroundStyle(Molten.Text.primary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("TITLE")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("Title", text: $title)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                TextField("Description", text: $description)
                    .font(.moltenBody(14))
                    .foregroundStyle(Molten.Text.primary)
                    .tint(Molten.Accent.primary)
                    .glassSearch()
            }

            // Color
            VStack(alignment: .leading, spacing: 6) {
                Text("COLOR")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                HStack(spacing: 10) {
                    ForEach(colorOptions, id: \.name) { opt in
                        Circle()
                            .fill(opt.color)
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: selectedColor == opt.name ? 2 : 0)
                            )
                            .onTapGesture { selectedColor = opt.name }
                    }
                }
            }

            // Icon
            VStack(alignment: .leading, spacing: 6) {
                Text("ICON")
                    .font(.moltenSmall())
                    .tracking(1.5)
                    .foregroundStyle(Molten.Text.tertiary)
                HStack(spacing: 10) {
                    ForEach(iconOptions, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 16))
                            .foregroundStyle(selectedIcon == icon ? Molten.Accent.primary : Molten.Text.tertiary)
                            .frame(width: 34, height: 34)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Molten.Accent.primary.opacity(0.15) : Color.white.opacity(0.04))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIcon == icon ? Molten.Accent.primary.opacity(0.3) : Molten.Card.border, lineWidth: 1)
                            )
                            .onTapGesture { selectedIcon = icon }
                    }
                }
            }

            Spacer()

            Button {
                onSave(title, description, selectedIcon, selectedColor)
                dismiss()
            } label: {
                Text("Save Changes")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Molten.Accent.primary)
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 8, y: 4)
            }
            .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(title.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
        }
        .padding(24)
    }
}
