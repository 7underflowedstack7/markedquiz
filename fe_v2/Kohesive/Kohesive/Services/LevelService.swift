import Foundation

// MARK: - Level Models

struct LevelData: Codable {
    let totalXp: Int
    let level: Int
    let xpForNextLevel: Int
    let xpInCurrentLevel: Int
    let goalText: String?
    let goalTarget: Int?
    let goalCurrent: Int
    let goalType: String?

    enum CodingKeys: String, CodingKey {
        case level
        case totalXp = "total_xp"
        case xpForNextLevel = "xp_for_next_level"
        case xpInCurrentLevel = "xp_in_current_level"
        case goalText = "goal_text"
        case goalTarget = "goal_target"
        case goalCurrent = "goal_current"
        case goalType = "goal_type"
    }
}

struct XPEvent: Codable, Identifiable {
    let id: Int
    let xpAmount: Int
    let source: String
    let description: String?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, source, description
        case xpAmount = "xp_amount"
        case createdAt = "created_at"
    }
}

struct XPAwardRequest: Codable {
    let source: String
    let amount: Int
    let description: String?
}

struct GoalUpdateRequest: Codable {
    let goalText: String?
    let goalTarget: Int?
    let goalCurrent: Int?
    let goalType: String?

    enum CodingKeys: String, CodingKey {
        case goalText = "goal_text"
        case goalTarget = "goal_target"
        case goalCurrent = "goal_current"
        case goalType = "goal_type"
    }
}

// MARK: - Level Service

@Observable
@MainActor
final class LevelService {
    private(set) var levelData: LevelData?
    private(set) var recentEvents: [XPEvent] = []
    private(set) var isLoading = false
    var error: String?

    private let baseURL = "https://markedquiz.onrender.com/api/level"

    // MARK: - Fetch Level

    func fetchLevel(token: String?) async {
        guard let token else { return }
        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            levelData = try JSONDecoder.iso8601.decode(LevelData.self, from: data)
        } catch { }
    }

    // MARK: - Award XP

    @discardableResult
    func awardXP(source: String, amount: Int, description: String? = nil, token: String?) async -> LevelData? {
        guard let token else { return nil }
        error = nil

        var request = URLRequest(url: URL(string: "\(baseURL)/xp")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = XPAwardRequest(source: source, amount: amount, description: description)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to award XP"
                return nil
            }
            let updated = try JSONDecoder.iso8601.decode(LevelData.self, from: data)
            levelData = updated
            return updated
        } catch {
            self.error = "Network error"
            return nil
        }
    }

    // MARK: - Update Goal

    @discardableResult
    func updateGoal(text: String?, target: Int?, current: Int?, type: String?, token: String?) async -> LevelData? {
        guard let token else { return nil }
        error = nil

        var request = URLRequest(url: URL(string: "\(baseURL)/goal")!)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GoalUpdateRequest(goalText: text, goalTarget: target, goalCurrent: current, goalType: type)
        request.httpBody = try? JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                error = "Failed to update goal"
                return nil
            }
            let updated = try JSONDecoder.iso8601.decode(LevelData.self, from: data)
            levelData = updated
            return updated
        } catch {
            self.error = "Network error"
            return nil
        }
    }

    // MARK: - Fetch History

    func fetchHistory(token: String?) async {
        guard let token else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/history")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            recentEvents = try JSONDecoder.iso8601.decode([XPEvent].self, from: data)
        } catch { }
    }

    // MARK: - Computed

    var level: Int { levelData?.level ?? 1 }
    var totalXP: Int { levelData?.totalXp ?? 0 }
    var xpForNextLevel: Int { levelData?.xpForNextLevel ?? 100 }
    var xpInCurrentLevel: Int { levelData?.xpInCurrentLevel ?? 0 }
    var xpProgress: Double {
        guard xpForNextLevel > 0 else { return 0 }
        return Double(xpInCurrentLevel) / Double(xpForNextLevel)
    }
    var goalText: String? { levelData?.goalText }
    var goalTarget: Int? { levelData?.goalTarget }
    var goalCurrent: Int { levelData?.goalCurrent ?? 0 }
    var goalType: String? { levelData?.goalType }
    var goalProgress: Double {
        guard let target = goalTarget, target > 0 else { return 0 }
        return min(1.0, Double(goalCurrent) / Double(target))
    }
}
