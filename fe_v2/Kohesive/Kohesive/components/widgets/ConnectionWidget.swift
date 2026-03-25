import SwiftUI

// MARK: - Connection Dashboard Widget (2x2: Render + Tailscale)

struct ConnectionWidget: View {
    @Environment(RemoteLLMService.self) private var llm

    // Render state
    @State private var renderConnected = false
    @State private var renderLatencyMs: Int?
    @State private var renderUptime = "\u{2014}"
    @State private var renderRequests = 0

    // Tailscale state
    @State private var tsConnected = false
    @State private var tsLatencyMs: Int?
    @State private var tsUptime = "\u{2014}"
    @State private var tsRequests = 0
    @State private var tsModelLoaded = false

    @State private var pulsing = false
    @State private var sessionStart: Date?

    private let green = Color(hex: 0x4ADE80)
    private let yellow = Color(hex: 0xFACC15)
    private let red = Color(hex: 0xF87171)
    private let renderHealthURL = URL(string: "https://markedquiz.onrender.com/api/health")!

    private func statusColor(connected: Bool, latency: Int?) -> Color {
        guard connected, let ms = latency else { return red }
        return ms < 200 ? green : ms < 500 ? yellow : red
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header
            HStack {
                Text("Connections")
                    .font(.custom("Georgia", size: 16).weight(.semibold))
                    .foregroundStyle(Molten.Text.primary)
                Spacer()
                Button(action: {
                    Task {
                        await pingRender()
                        await pingTailscale()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(Molten.Text.secondary)
                }
            }

            // 2x2 grid: top = rings, bottom = stats
            HStack(alignment: .top, spacing: 12) {
                // LEFT: Render
                ConnectionPanel(
                    label: "Render",
                    icon: renderConnected ? "server.rack" : "xmark.icloud",
                    connected: renderConnected,
                    statusColor: statusColor(connected: renderConnected, latency: renderLatencyMs),
                    pulsing: pulsing,
                    latencyMs: renderLatencyMs,
                    uptime: renderUptime,
                    requests: renderRequests,
                    modelPill: nil
                )

                // Divider
                Rectangle()
                    .fill(Molten.Card.border)
                    .frame(width: 1)
                    .padding(.vertical, 4)

                // RIGHT: Tailscale
                ConnectionPanel(
                    label: "Tailscale",
                    icon: tsConnected ? "lock.fill" : "lock.open",
                    connected: tsConnected,
                    statusColor: statusColor(connected: tsConnected, latency: tsLatencyMs),
                    pulsing: pulsing,
                    latencyMs: tsLatencyMs,
                    uptime: tsUptime,
                    requests: tsRequests,
                    modelPill: tsConnected ? (tsModelLoaded ? "Model: Ready" : "Model: Loading") : nil
                )
            }
        }
        .glassCard(radius: Molten.Radius.md, padding: 14)
        .onAppear {
            pulsing = true
            sessionStart = sessionStart ?? Date()
            Task {
                await pingRender()
                await pingTailscale()
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await pingRender()
                await pingTailscale()
            }
        }
    }

    // MARK: - Render ping

    private func pingRender() async {
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await URLSession.shared.data(from: renderHealthURL)
            let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            await MainActor.run {
                renderLatencyMs = ms
                renderConnected = (response as? HTTPURLResponse)?.statusCode == 200
                renderRequests += 1
                updateUptime()
            }
        } catch {
            await MainActor.run {
                renderConnected = false
                renderLatencyMs = nil
                renderRequests += 1
                updateUptime()
            }
        }
    }

    // MARK: - Tailscale ping

    private func pingTailscale() async {
        guard llm.isConfigured else {
            await MainActor.run {
                tsConnected = false
                tsLatencyMs = nil
                tsModelLoaded = false
            }
            return
        }
        let start = CFAbsoluteTimeGetCurrent()
        let result = await llm.checkHealth()
        let ms = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
        await MainActor.run {
            tsConnected = result.reachable
            tsLatencyMs = result.reachable ? ms : nil
            tsModelLoaded = result.modelLoaded
            tsRequests += 1
            updateUptime()
        }
    }

    private func updateUptime() {
        guard let start = sessionStart else { return }
        let elapsed = Int(Date().timeIntervalSince(start))
        let h = elapsed / 3600
        let m = (elapsed % 3600) / 60
        let str = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        renderUptime = str
        tsUptime = str
    }
}

// MARK: - Single Connection Panel (one side of the 2x2)

struct ConnectionPanel: View {
    let label: String
    let icon: String
    let connected: Bool
    let statusColor: Color
    let pulsing: Bool
    let latencyMs: Int?
    let uptime: String
    let requests: Int
    let modelPill: String?

    var body: some View {
        VStack(spacing: 8) {
            // Ring + icon
            ZStack {
                Circle()
                    .stroke(statusColor.opacity(pulsing ? 0.35 : 0.15), lineWidth: 2)
                    .frame(width: 60, height: 60)
                    .shadow(color: pulsing && connected ? statusColor.opacity(0.12) : .clear, radius: 12)
                    .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: pulsing)

                Circle()
                    .fill(.thinMaterial)
                    .overlay(Circle().fill(Molten.Card.bg))
                    .overlay(Circle().stroke(statusColor.opacity(0.2), lineWidth: 1))
                    .frame(width: 42, height: 42)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, y: 3)

                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(statusColor.opacity(0.8))
            }

            // Label
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Molten.Text.primary)

            // Status
            Text(connected ? "CONNECTED" : "OFFLINE")
                .font(.system(size: 8, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(statusColor)

            // Model pill (Tailscale only)
            if let modelPill {
                let isReady = modelPill.contains("Ready")
                Text(modelPill)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(isReady ? Color(hex: 0x4ADE80) : Color(hex: 0xFACC15))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill((isReady ? Color(hex: 0x4ADE80) : Color(hex: 0xFACC15)).opacity(0.1))
                            .overlay(
                                Capsule().stroke(
                                    (isReady ? Color(hex: 0x4ADE80) : Color(hex: 0xFACC15)).opacity(0.2),
                                    lineWidth: 1
                                )
                            )
                    )
            }

            // Stats
            VStack(spacing: 4) {
                ConnectionStat(
                    value: latencyMs.map { "\($0)" } ?? "\u{2014}",
                    label: "LATENCY",
                    color: statusColor
                )
                ConnectionStat(
                    value: uptime,
                    label: "UPTIME",
                    color: Molten.Accent.warm
                )
                ConnectionStat(
                    value: "\(requests)",
                    label: "REQUESTS",
                    color: Molten.Accent.primary
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Connection Stat Row

struct ConnectionStat: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack {
            Text(value)
                .font(.custom("Georgia", size: 16).weight(.regular))
                .foregroundStyle(color)
            Spacer()
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .tracking(0.5)
                .foregroundStyle(Molten.Text.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Molten.Card.border, lineWidth: 0.5))
        )
    }
}

// MARK: - Section Label

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.moltenSmall())
            .tracking(1.5)
            .foregroundStyle(Molten.Text.tertiary)
            .padding(.leading, 4)
            .padding(.bottom, 12)
    }
}
