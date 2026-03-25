import Foundation
import SwiftUI
import LocalAuthentication

@Observable
@MainActor
final class AuthService {
    private(set) var currentUser: UserResponse?
    private(set) var isLoading = false
    private(set) var isUnlocked = false
    private(set) var isRestoringSession = false
    var error: String?

    private let baseURL = "https://markedquiz.onrender.com/api/auth"

    // MARK: - Token Access

    var accessToken: String? {
        KeychainHelper.read("auth_token")
    }

    private var refreshToken: String? {
        KeychainHelper.read("refresh_token")
    }

    var isLoggedIn: Bool {
        accessToken != nil
    }

    var hasStoredSession: Bool {
        refreshToken != nil
    }

    // MARK: - Session Restoration (Option 1: auto-refresh on launch)

    /// Remove access tokens that linger without a refresh token.
    /// This can happen if a partial Keychain write occurs or the refresh
    /// token expires server-side and gets cleaned up on a failed refresh.
    func cleanupOrphanedTokens() {
        if accessToken != nil && refreshToken == nil {
            KeychainHelper.delete("auth_token")
        }
    }

    /// Call on app launch. If a refresh token exists, silently refreshes
    /// the access token and restores the session.
    func restoreSession() async {
        guard hasStoredSession else {
            cleanupOrphanedTokens()
            return
        }
        isRestoringSession = true
        defer { isRestoringSession = false }

        await refreshAccessToken()
        if isLoggedIn {
            await fetchMe()
            isUnlocked = true
        }
    }

    // MARK: - Passcode Auth (Option 2: device passcode gate)

    /// Prompts for the device lock screen passcode (or biometric if available).
    /// Uses `deviceOwnerAuthentication` policy which accepts passcode as fallback.
    func authenticateWithPasscode() async -> Bool {
        let context = LAContext()
        // Allow passcode fallback immediately (don't require biometric first)
        context.localizedFallbackTitle = "Use Passcode"

        var authError: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            // No passcode set on device — skip auth, just restore
            await restoreSession()
            return isLoggedIn
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Kohesive to access your data"
            )
            if success {
                await restoreSession()
                return isLoggedIn
            }
            return false
        } catch {
            self.error = "Authentication cancelled"
            return false
        }
    }

    // MARK: - Auth Actions

    func login(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let body = LoginRequest(email: email, password: password)
            let tokens: TokenResponse = try await post("\(baseURL)/login", body: body)
            saveTokens(tokens)
            await fetchMe()
            isUnlocked = true
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = "Login failed"
        }
    }

    func register(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let body = LoginRequest(email: email, password: password)
            let tokens: TokenResponse = try await post("\(baseURL)/register", body: body, expectedStatus: 201)
            saveTokens(tokens)
            await fetchMe()
            isUnlocked = true
        } catch let err as APIError {
            error = err.message
        } catch {
            self.error = "Registration failed"
        }
    }

    func refreshAccessToken() async {
        guard let refresh = refreshToken else { return }

        do {
            let body = ["refresh_token": refresh]
            let tokens: TokenResponse = try await post("\(baseURL)/refresh", body: body)
            saveTokens(tokens)
        } catch {
            logout()
        }
    }

    func fetchMe() async {
        guard let token = accessToken else { return }

        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/me")!)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            currentUser = try JSONDecoder.iso8601.decode(UserResponse.self, from: data)
        } catch {
            // Silent fail for /me
        }
    }

    func logout() {
        KeychainHelper.delete("auth_token")
        KeychainHelper.delete("refresh_token")
        currentUser = nil
        isUnlocked = false
    }

    // MARK: - Helpers

    private func saveTokens(_ tokens: TokenResponse) {
        KeychainHelper.save(tokens.accessToken, for: "auth_token")
        KeychainHelper.save(tokens.refreshToken, for: "refresh_token")
    }

    private func post<T: Codable, R: Decodable>(_ urlString: String, body: T, expectedStatus: Int = 200) async throws -> R {
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "Invalid response")
        }
        guard http.statusCode == expectedStatus else {
            if let detail = try? JSONDecoder().decode([String: String].self, from: data),
               let msg = detail["detail"] {
                throw APIError(message: msg)
            }
            throw APIError(message: "Request failed (\(http.statusCode))")
        }
        return try JSONDecoder.iso8601.decode(R.self, from: data)
    }
}

struct APIError: Error {
    let message: String
}

extension JSONDecoder {
    static let iso8601: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
