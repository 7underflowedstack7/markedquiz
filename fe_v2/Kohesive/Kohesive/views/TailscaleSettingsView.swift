import SwiftUI

/// Tailscale Agent Connection settings — ported from tailscale_components.html View 1
struct TailscaleSettingsView: View {
    @AppStorage("ts_url") private var agentURL = ""
    @AppStorage("ts_api_key") private var apiKey = ""
    @State private var isTesting = false
    @State private var testResult: TestResult?
    @State private var appeared = false

    private let green = Color(hex: 0x4ADE80)
    private let red = Color(hex: 0xF87171)

    enum TestResult {
        case success(latency: Int)
        case failure(String)

        var isSuccess: Bool {
            if case .success = self { return true }
            return false
        }
    }

    var body: some View {
        ZStack {
            BlobBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header (settings-header style)
                    HStack(spacing: 10) {
                        Text("◆")
                            .font(.system(size: 18))
                            .foregroundStyle(Molten.Accent.primary)
                        Text("Agent Connection")
                            .font(.custom("Georgia", size: 24).weight(.regular))
                            .foregroundStyle(Molten.Text.primary)
                    }
                    .padding(.bottom, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)

                    // MARK: - Configuration
                    SectionLabel(text: "Configuration")

                    // URL field (config-field style — capsule with icon)
                    HStack(spacing: 10) {
                        Text("🌐")
                            .font(.system(size: 16))
                        TextField("http://100.64.0.3:8080", text: $agentURL)
                            .font(.moltenBody(14))
                            .foregroundStyle(agentURL.isEmpty ? Molten.Text.secondary : Molten.Text.primary)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                    }
                    .glassSearch()
                    .padding(.bottom, 12)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.05), value: appeared)

                    // API Key field (config-field style)
                    HStack(spacing: 10) {
                        Text("🔑")
                            .font(.system(size: 16))
                        SecureField("API Key", text: $apiKey)
                            .font(.moltenBody(14))
                            .foregroundStyle(apiKey.isEmpty ? Molten.Text.secondary : Molten.Text.primary)
                    }
                    .glassSearch()
                    .padding(.bottom, 18)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.1), value: appeared)

                    // MARK: - Status
                    SectionLabel(text: "Status")

                    // Status row (status-row style — dot + text)
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                                .shadow(color: statusColor.opacity(0.5), radius: 6)

                            // Pulse ring for connected state
                            if testResult?.isSuccess == true {
                                Circle()
                                    .stroke(green.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                    .modifier(StatusPulseModifier())
                            }
                        }
                        .frame(width: 18, height: 18)

                        Text(statusText)
                            .font(.system(size: 14))
                            .foregroundStyle(statusColor)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.15), value: appeared)

                    // Test Connection button (test-btn style)
                    Button(action: testConnection) {
                        HStack(spacing: 8) {
                            if isTesting {
                                ProgressView()
                                    .tint(Molten.Accent.primary)
                                    .scaleEffect(0.8)
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                                .font(.system(size: 14, weight: .medium))
                                .tracking(0.5)
                        }
                        .foregroundStyle(Molten.Accent.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            Capsule().stroke(Molten.Accent.primary, lineWidth: 1.5)
                        )
                        .shadow(color: Molten.Shadow.deep, radius: 12, y: 5)
                    }
                    .disabled(isTesting || agentURL.isEmpty)
                    .opacity(agentURL.isEmpty ? 0.4 : 1)
                    .padding(.bottom, 14)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: appeared)

                    // Health result (health-result style)
                    if let result = testResult {
                        HStack(spacing: 10) {
                            switch result {
                            case .success(let latency):
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16))
                                    .foregroundStyle(green)
                                Text("Agent reachable · \(latency)ms")
                                    .font(.system(size: 13))
                                    .foregroundStyle(green)
                            case .failure(let msg):
                                Image(systemName: "xmark")
                                    .font(.system(size: 16))
                                    .foregroundStyle(red)
                                Text(msg)
                                    .font(.system(size: 13))
                                    .foregroundStyle(red)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            Capsule()
                                .fill(result.isSuccess ? green.opacity(0.08) : red.opacity(0.08))
                                .overlay(
                                    Capsule().stroke(
                                        result.isSuccess ? green.opacity(0.15) : red.opacity(0.15),
                                        lineWidth: 1
                                    )
                                )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("Tailscale")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { appeared = true }
    }

    // MARK: - Status

    private var statusColor: Color {
        guard testResult != nil else { return Color.white.opacity(0.25) }
        return testResult?.isSuccess == true ? green : red
    }

    private var statusText: String {
        guard let result = testResult else { return "Not tested" }
        return result.isSuccess ? "Connected" : "Unreachable"
    }

    // MARK: - Test Connection

    private func testConnection() {
        isTesting = true
        testResult = nil

        Task {
            let base = agentURL.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let healthURL = "\(base)/health"
            guard let url = URL(string: healthURL) else {
                await MainActor.run {
                    testResult = .failure("Invalid URL")
                    isTesting = false
                }
                return
            }

            let start = CFAbsoluteTimeGetCurrent()
            do {
                var request = URLRequest(url: url)
                request.timeoutInterval = 10
                if !apiKey.isEmpty {
                    request.setValue(apiKey, forHTTPHeaderField: "X-Agent-Key")
                }
                let (_, response) = try await URLSession.shared.data(for: request)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let ms = Int(elapsed * 1000)

                await MainActor.run {
                    if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                        withAnimation { testResult = .success(latency: ms) }
                    } else {
                        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                        withAnimation { testResult = .failure("HTTP \(code)") }
                    }
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    withAnimation { testResult = .failure(error.localizedDescription) }
                    isTesting = false
                }
            }
        }
    }
}

private struct StatusPulseModifier: ViewModifier {
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 1.6 : 1)
            .opacity(pulsing ? 0 : 1)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: false), value: pulsing)
            .onAppear { pulsing = true }
    }
}
