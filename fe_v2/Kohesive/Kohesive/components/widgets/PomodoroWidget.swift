import SwiftUI

// MARK: - Pomodoro Timer Widget (fully functional)

struct PomodoroWidget: View {
    @Environment(PomodoroTimer.self) private var timer
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    if timer.isRunning && !timer.isPaused {
                        Circle()
                            .fill(timer.isBreak ? Color(hex: 0x2DD4A0) : Molten.Accent.primary)
                            .frame(width: 7, height: 7)
                            .modifier(PulseModifier())
                    }
                    Text(timer.isRunning ? timer.currentMode.label : "Focus Timer")
                        .font(.custom("Georgia", size: 16).weight(.medium))
                        .foregroundStyle(Molten.Text.primary)
                        .lineLimit(1)
                }
                Spacer()
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(Molten.Text.secondary)
                        .frame(width: 26, height: 26)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Molten.Card.border, lineWidth: 1)
                        )
                }
            }
            .padding(.bottom, 14)

            // Ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 5)
                    .frame(width: 100, height: 100)
                Circle()
                    .trim(from: 0, to: timer.progress)
                    .stroke(
                        AngularGradient(
                            colors: timer.isBreak
                                ? [Color(hex: 0x2DD4A0), Color(hex: 0x5EE8C2)]
                                : [Molten.Accent.primary, Molten.Accent.warm],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.progress)

                Text(timer.timeString)
                    .font(.custom("Georgia", size: 22).weight(.semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .monospacedDigit()
            }
            .padding(.bottom, 4)

            Text(timer.isRunning
                 ? "Session \(timer.currentSession) of \(timer.totalSessions)"
                 : "Ready to focus")
                .font(.system(size: 10))
                .foregroundStyle(Molten.Text.tertiary)
                .padding(.bottom, 12)

            // Mode pills (only when idle)
            if !timer.isRunning {
                HStack(spacing: 4) {
                    ModePill(label: "Focus", isActive: timer.currentMode == .focus) {
                        timer.selectMode(.focus)
                    }
                    ModePill(label: "Short", isActive: timer.currentMode == .shortBreak) {
                        timer.selectMode(.shortBreak)
                    }
                }
                .padding(.bottom, 10)
            }

            // Action buttons
            if timer.isRunning {
                HStack(spacing: 6) {
                    Button(action: { timer.isPaused ? timer.resume() : timer.pause() }) {
                        Text(timer.isPaused ? "Resume" : "Pause")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Molten.Text.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Molten.Card.border, lineWidth: 1)
                            )
                    }
                    Button(action: { timer.skip() }) {
                        Text("Skip \u{2192}")
                            .font(.system(size: 11))
                            .foregroundStyle(Molten.Text.tertiary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                    }
                }
                .padding(.bottom, 10)

                // Progress segments
                HStack(spacing: 4) {
                    ForEach(0..<timer.totalSessions, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                i < timer.sessionsCompleted
                                    ? AnyShapeStyle(Molten.Accent.primary)
                                    : i == timer.sessionsCompleted && timer.currentMode == .focus
                                        ? AnyShapeStyle(LinearGradient(colors: [Molten.Accent.primary, Molten.Accent.warm], startPoint: .leading, endPoint: .trailing))
                                        : AnyShapeStyle(Color.white.opacity(0.08))
                            )
                            .frame(height: 4)
                    }
                }
            } else {
                Button(action: { timer.start() }) {
                    Text("Start")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Molten.Text.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Molten.Accent.primary)
                        )
                        .shadow(color: Molten.Shadow.fab, radius: 7, y: 3)
                }
            }

            // Progress segments (visible when idle with completed sessions)
            if !timer.isRunning && timer.sessionsCompleted > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<timer.totalSessions, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                i < timer.sessionsCompleted
                                    ? AnyShapeStyle(Molten.Accent.primary)
                                    : AnyShapeStyle(Color.white.opacity(0.08))
                            )
                            .frame(height: 4)
                    }
                }
                .padding(.top, 4)
            }
        }
        .glassCard(radius: Molten.Radius.md, padding: 14)
        .sheet(isPresented: $showSettings) {
            PomodoroSettingsSheet()
                .environment(timer)
        }
    }
}

// MARK: - Mode Pill

struct ModePill: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isActive ? Molten.Text.primary : Molten.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isActive ? Molten.Accent.primarySoft : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? Molten.Accent.primary : Molten.Card.border, lineWidth: 1)
                )
        }
    }
}

// MARK: - Pulse Modifier

struct PulseModifier: ViewModifier {
    @State private var pulsing = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(pulsing ? 0.75 : 1)
            .opacity(pulsing ? 0.4 : 1)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}
