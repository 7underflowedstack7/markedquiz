import Foundation

// MARK: - Habits Models

struct HabitItem: Codable, Identifiable, Hashable {
    static func == (lhs: HabitItem, rhs: HabitItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    let id: Int
    var title: String
    var description: String
    var icon: String
    var color: String
    var frequency: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, description, icon, color, frequency
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct HabitEntry: Codable, Identifiable {
    let id: Int
    let habitId: Int
    let date: String
    var completed: Bool

    enum CodingKeys: String, CodingKey {
        case id, date, completed
        case habitId = "habit_id"
    }
}

nonisolated struct StreakResponse: Codable, Sendable {
    let habitId: Int
    let streak: Int

    enum CodingKeys: String, CodingKey {
        case habitId = "habit_id"
        case streak
    }
}

// MARK: - Service

@Observable
@MainActor
final class HabitsService {
    private(set) var habits: [HabitItem] = []
    private(set) var entries: [HabitEntry] = []
    private(set) var streaks: [Int: Int] = [:]  // habitId → streak
    private(set) var isLoading = false

    private let baseURL = "https://markedquiz.onrender.com/api/habits"

    // MARK: - Queries

    func isCompleted(_ habit: HabitItem, on date: Date) -> Bool {
        let dateStr = Self.dateFormatter.string(from: date)
        return entries.contains { $0.habitId == habit.id && $0.date == dateStr && $0.completed }
    }

    func completedCount(on date: Date) -> Int {
        let dateStr = Self.dateFormatter.string(from: date)
        return entries.filter { $0.date == dateStr && $0.completed }.count
    }

    func streak(for habit: HabitItem) -> Int {
        streaks[habit.id] ?? 0
    }

    // MARK: - Fetch All

    func fetchAll(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }

        async let h: Void = fetchHabits(token: token)
        async let e: Void = fetchEntries(token: token)
        _ = await (h, e)
        await fetchAllStreaks(token: token)
    }

    private func fetchHabits(token: String) async {
        guard let url = URL(string: baseURL) else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            habits = try Self.decoder.decode([HabitItem].self, from: data)
        } catch { }
    }

    private func fetchEntries(token: String) async {
        let from = Self.dateFormatter.string(from: Calendar.current.date(byAdding: .day, value: -30, to: Date())!)
        let to = Self.dateFormatter.string(from: Date())
        guard let url = URL(string: "\(baseURL)/entries/list?from=\(from)&to=\(to)") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            entries = try Self.decoder.decode([HabitEntry].self, from: data)
        } catch { }
    }

    private func fetchAllStreaks(token: String) async {
        let decoder = Self.decoder  // capture on main actor before entering task group
        await withTaskGroup(of: (Int, Int)?.self) { group in
            for habit in habits {
                group.addTask { [baseURL] in
                    guard let url = URL(string: "\(baseURL)/\(habit.id)/streak") else { return nil }
                    var request = URLRequest(url: url)
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    do {
                        let (data, response) = try await URLSession.shared.data(for: request)
                        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
                        let sr = try decoder.decode(StreakResponse.self, from: data)
                        return (sr.habitId, sr.streak)
                    } catch { return nil }
                }
            }
            for await result in group {
                if let (id, streak) = result {
                    streaks[id] = streak
                }
            }
        }
    }

    // MARK: - Toggle

    func toggleHabit(_ habit: HabitItem, on date: Date, token: String?) async {
        guard let token else { return }
        let dateStr = Self.dateFormatter.string(from: date)
        guard let url = URL(string: "\(baseURL)/\(habit.id)/toggle") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(["date": dateStr])

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let entry = try Self.decoder.decode(HabitEntry.self, from: data)

            // Update local state
            if let idx = entries.firstIndex(where: { $0.habitId == habit.id && $0.date == dateStr }) {
                entries[idx] = entry
            } else {
                entries.append(entry)
            }
        } catch { }
    }

    // MARK: - Create

    func createHabit(title: String, description: String = "", icon: String = "flame.fill", color: String = "teal", frequency: String = "daily", token: String?) async {
        guard let token else { return }
        guard let url = URL(string: baseURL) else { return }

        let body: [String: String] = [
            "title": title,
            "description": description,
            "icon": icon,
            "color": color,
            "frequency": frequency,
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 201 else { return }
            let habit = try Self.decoder.decode(HabitItem.self, from: data)
            habits.append(habit)
        } catch { }
    }

    // MARK: - Update

    func updateHabit(_ habit: HabitItem, title: String?, description: String?, icon: String?, color: String?, token: String?) async {
        guard let token else { return }
        guard let url = URL(string: "\(baseURL)/\(habit.id)") else { return }

        var body: [String: String] = [:]
        if let title { body["title"] = title }
        if let description { body["description"] = description }
        if let icon { body["icon"] = icon }
        if let color { body["color"] = color }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let updated = try Self.decoder.decode(HabitItem.self, from: data)
            if let idx = habits.firstIndex(where: { $0.id == habit.id }) {
                habits[idx] = updated
            }
        } catch { }
    }

    // MARK: - Delete

    func deleteHabit(_ habit: HabitItem, token: String?) async {
        guard let token else { return }
        guard let url = URL(string: "\(baseURL)/\(habit.id)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            habits.removeAll { $0.id == habit.id }
            entries.removeAll { $0.habitId == habit.id }
            streaks.removeValue(forKey: habit.id)
        } catch { }
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formats = [
                "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
                "yyyy-MM-dd'T'HH:mm:ss",
            ]
            for fmt in formats {
                let f = DateFormatter()
                f.dateFormat = fmt
                f.locale = Locale(identifier: "en_US_POSIX")
                if let date = f.date(from: str) { return date }
            }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = iso.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(str)")
        }
        return d
    }()
}
