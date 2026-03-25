import SwiftUI

// MARK: - Pomodoro Settings Sheet

struct PomodoroSettingsSheet: View {
    @Environment(PomodoroTimer.self) private var timer
    @Environment(\.dismiss) private var dismiss
    @State private var showResetConfirm = false

    var body: some View {
        @Bindable var timer = timer

        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // MARK: Durations
                    SettingsSection(title: "DURATIONS") {
                        DurationRow(label: "Focus", minutes: Binding(
                            get: { timer.focusDuration / 60 },
                            set: { timer.focusDuration = $0 * 60 }
                        ))
                        Divider().overlay(Color.white.opacity(0.06))
                        DurationRow(label: "Short Break", minutes: Binding(
                            get: { timer.shortBreakDuration / 60 },
                            set: { timer.shortBreakDuration = $0 * 60 }
                        ))
                        Divider().overlay(Color.white.opacity(0.06))
                        HStack {
                            Text("Sessions")
                                .font(.system(size: 14))
                                .foregroundStyle(Molten.Text.primary)
                            Spacer()
                            Stepper(value: $timer.totalSessions, in: 1...10) {
                                Text("\(timer.totalSessions)")
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Molten.Accent.primary)
                                    .frame(width: 30, alignment: .trailing)
                            }
                            .tint(Molten.Accent.primary)
                        }
                    }

                    // MARK: Presets
                    SettingsSection(title: "PRESETS") {
                        HStack(spacing: 8) {
                            ForEach(PomodoroTimer.presets, id: \.label) { preset in
                                let isActive = timer.focusDuration == preset.focus * 60
                                    && timer.shortBreakDuration == preset.short * 60

                                Button {
                                    timer.applyPreset(preset)
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(preset.label)
                                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(isActive ? Molten.Text.primary : Molten.Text.secondary)
                                        Text("focus / break")
                                            .font(.system(size: 8))
                                            .foregroundStyle(Molten.Text.tertiary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isActive ? Molten.Accent.primary.opacity(0.15) : Molten.Card.bg)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                isActive ? Molten.Accent.primary.opacity(0.4) : Molten.Card.border,
                                                lineWidth: 1
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(timer.isRunning)
                                .opacity(timer.isRunning ? 0.5 : 1)
                            }
                        }
                    }

                    // MARK: Sound
                    SettingsSection(title: "SOUND") {
                        Toggle(isOn: $timer.soundEnabled) {
                            Text("Play Sound")
                                .font(.system(size: 14))
                                .foregroundStyle(Molten.Text.primary)
                        }
                        .tint(Molten.Accent.primary)

                        if timer.soundEnabled {
                            Divider().overlay(Color.white.opacity(0.06))

                            // Sound type picker
                            HStack {
                                Text("Sound")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Molten.Text.primary)
                                Spacer()
                                Menu {
                                    ForEach(CompletionSound.allCases) { sound in
                                        Button {
                                            timer.soundType = sound
                                            timer.playSound(sound)
                                        } label: {
                                            HStack {
                                                Text(sound.rawValue)
                                                if timer.soundType == sound {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(timer.soundType.rawValue)
                                            .font(.system(size: 13))
                                            .foregroundStyle(Molten.Accent.primary)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Molten.Text.tertiary)
                                    }
                                }

                                // Preview button
                                Button {
                                    timer.playSound(timer.soundType)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Molten.Text.secondary)
                                        .frame(width: 30, height: 30)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 7)
                                                .stroke(Molten.Card.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                            }

                            Divider().overlay(Color.white.opacity(0.06))

                            // Volume
                            HStack(spacing: 10) {
                                Image(systemName: "speaker.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Molten.Text.tertiary)
                                Slider(value: $timer.soundVolume, in: 0...1)
                                    .tint(Molten.Accent.primary)
                                Image(systemName: "speaker.wave.3.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Molten.Text.tertiary)
                            }
                        }
                    }

                    // MARK: Haptic
                    SettingsSection(title: "HAPTIC") {
                        Toggle(isOn: $timer.hapticEnabled) {
                            Text("Haptic Feedback")
                                .font(.system(size: 14))
                                .foregroundStyle(Molten.Text.primary)
                        }
                        .tint(Molten.Accent.primary)
                    }

                    // MARK: Reset
                    Button {
                        showResetConfirm = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 13, weight: .medium))
                            Text("Reset Timer")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.red.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.red.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(.red.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Molten.Accent.primary)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(Molten.BG.deep)
        .preferredColorScheme(.dark)
        .alert("Reset Timer?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                timer.reset()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will stop the current session and reset all progress.")
        }
    }
}

// MARK: - Settings Section Container

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .tracking(1)
                .foregroundStyle(Molten.Text.tertiary)
                .padding(.bottom, 8)
                .padding(.leading, 4)

            VStack(spacing: 10) {
                content
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Molten.Card.bg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Molten.Card.border, lineWidth: 1)
                    )
            )
        }
    }
}

// MARK: - Duration Row

struct DurationRow: View {
    let label: String
    @Binding var minutes: Int

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Molten.Text.primary)
            Spacer()
            HStack(spacing: 6) {
                Button {
                    if minutes > 1 { minutes -= 1 }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Molten.Text.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Molten.Card.bg)
                                .overlay(Circle().stroke(Molten.Card.border, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Text("\(minutes)")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Molten.Accent.primary)
                    .frame(width: 32, alignment: .center)

                Button {
                    if minutes < 120 { minutes += 1 }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Molten.Text.secondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Molten.Card.bg)
                                .overlay(Circle().stroke(Molten.Card.border, lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)

                Text("min")
                    .font(.system(size: 11))
                    .foregroundStyle(Molten.Text.tertiary)
            }
        }
    }
}
