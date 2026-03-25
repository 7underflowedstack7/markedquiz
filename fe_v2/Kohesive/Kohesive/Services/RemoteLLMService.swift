import Foundation

// MARK: - LLM Errors

enum LLMError: LocalizedError {
    case notConfigured
    case unauthorized
    case rateLimited
    case serviceUnavailable
    case gatewayTimeout
    case serverError(Int)
    case invalidURL
    case streamInterrupted

    var errorDescription: String? {
        switch self {
        case .notConfigured:      "Agent not configured — set URL in Tailscale settings"
        case .unauthorized:       "Invalid API key — check Tailscale settings"
        case .rateLimited:        "Rate limited — try again shortly"
        case .serviceUnavailable: "Agent service unavailable"
        case .gatewayTimeout:     "Agent timed out — model may still be loading"
        case .serverError(let c): "Agent error (\(c))"
        case .invalidURL:         "Agent URL is malformed"
        case .streamInterrupted:  "Stream ended unexpectedly"
        }
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: String  // "user" or "assistant"
    var content: String
    let timestamp: Date

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - RemoteLLMService

@Observable
@MainActor
final class RemoteLLMService {

    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }

    var connectionState: ConnectionState = .disconnected

    /// Reads from the same AppStorage keys as TailscaleSettingsView
    var baseURL: String {
        UserDefaults.standard.string(forKey: "ts_url") ?? ""
    }

    var apiKey: String {
        UserDefaults.standard.string(forKey: "ts_api_key") ?? ""
    }

    var isConfigured: Bool { !baseURL.isEmpty }

    // MARK: - Chat (streaming)

    /// POST {baseURL}/chat with full message history. Yields plain-text chunks.
    func chat(
        messages: [(role: String, content: String)],
        token: String,
        systemPrompt: String = ""
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard isConfigured else { throw LLMError.notConfigured }
                    guard let url = URL(string: "\(baseURL)/chat") else { throw LLMError.invalidURL }

                    var payload: [String: Any] = [
                        "messages": messages.map { ["role": $0.role, "content": $0.content] }
                    ]
                    if !systemPrompt.isEmpty {
                        payload["system"] = systemPrompt
                    }
                    let body = try JSONSerialization.data(withJSONObject: payload)

                    var request = URLRequest(url: url, timeoutInterval: 120)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    if !apiKey.isEmpty {
                        request.setValue(apiKey, forHTTPHeaderField: "X-Agent-Key")
                    }
                    request.httpBody = body

                    await MainActor.run { connectionState = .connecting }

                    let (byteStream, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.streamInterrupted
                    }

                    switch http.statusCode {
                    case 200: break
                    case 401: throw LLMError.unauthorized
                    case 429: throw LLMError.rateLimited
                    case 503: throw LLMError.serviceUnavailable
                    case 504: throw LLMError.gatewayTimeout
                    default:  throw LLMError.serverError(http.statusCode)
                    }

                    await MainActor.run { connectionState = .connected }

                    var buffer = Data()
                    for try await byte in byteStream {
                        buffer.append(byte)
                        if let text = String(data: buffer, encoding: .utf8) {
                            continuation.yield(text)
                            buffer.removeAll(keepingCapacity: true)
                        }
                    }
                    if !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) {
                        continuation.yield(text)
                    }
                    continuation.finish()
                } catch {
                    await MainActor.run {
                        connectionState = .error(error.localizedDescription)
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Health Check

    func checkHealth() async -> (reachable: Bool, modelLoaded: Bool) {
        guard isConfigured, let url = URL(string: "\(baseURL)/health") else {
            return (false, false)
        }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "GET"
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Agent-Key")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return (true, false)
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let modelLoaded = json?["model_loaded"] as? Bool ?? false
            connectionState = .connected
            return (true, modelLoaded)
        } catch {
            connectionState = .error("Unreachable")
            return (false, false)
        }
    }
}
