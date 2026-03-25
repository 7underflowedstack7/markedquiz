import Foundation
import SwiftUI
import AVFoundation

// MARK: - Completion Sound

enum CompletionSound: String, CaseIterable, Identifiable {
    case triTone   = "Tri-Tone"
    case chime     = "Chime"
    case bloom     = "Bloom"
    case calypso   = "Calypso"
    case descent   = "Descent"
    case fanfare   = "Fanfare"
    case spell     = "Spell"
    case telegraph = "Telegraph"

    var id: String { rawValue }

    var filePath: String {
        switch self {
        case .triTone:  return "/System/Library/Audio/UISounds/sms-received1.caf"
        case .chime:    return "/System/Library/Audio/UISounds/sms-received4.caf"
        case .bloom:    return "/System/Library/Audio/UISounds/New/Bloom.caf"
        case .calypso:  return "/System/Library/Audio/UISounds/New/Calypso.caf"
        case .descent:  return "/System/Library/Audio/UISounds/New/Descent.caf"
        case .fanfare:  return "/System/Library/Audio/UISounds/New/Fanfare.caf"
        case .spell:    return "/System/Library/Audio/UISounds/New/Spell.caf"
        case .telegraph: return "/System/Library/Audio/UISounds/New/Telegraph.caf"
        }
    }
}

/// Full Pomodoro cycle: Focus → Short → Focus → Short → Focus → Short → Focus → Long
/// Auto-advances until user intervenes. Persists across tab switches and app backgrounding
/// via UserDefaults timestamps.
@Observable
@MainActor
final class PomodoroTimer {
    // MARK: - Published State

    private(set) var secondsRemaining: Int = 0
    private(set) var totalSeconds: Int = 0
    private(set) var isRunning = false
    private(set) var isPaused = false
    private(set) var currentSession: Int = 1   // 1-based
    private(set) var sessionsCompleted: Int = 0
    private(set) var currentMode: TimerMode = .focus

    // MARK: - Configuration

    var focusDuration: Int = 25 * 60 {
        didSet { if !isRunning { resetToIdle() }; persistSettings() }
    }
    var shortBreakDuration: Int = 5 * 60 {
        didSet { if !isRunning { resetToIdle() }; persistSettings() }
    }
    var longBreakDuration: Int = 15 * 60 {
        didSet { if !isRunning { resetToIdle() }; persistSettings() }
    }
    var totalSessions: Int = 4 {
        didSet { persistSettings() }
    }

    // MARK: - Sound & Haptic Settings

    var soundEnabled: Bool = true {
        didSet { persistSettings() }
    }
    var soundType: CompletionSound = .triTone {
        didSet { persistSettings() }
    }
    var soundVolume: Float = 0.7 {
        didSet { persistSettings() }
    }
    var hapticEnabled: Bool = true {
        didSet { persistSettings() }
    }

    // MARK: - Presets

    static let presets: [(label: String, focus: Int, short: Int, long: Int)] = [
        ("25/5/15", 25, 5, 15),
        ("50/10/30", 50, 10, 30),
        ("90/20/45", 90, 20, 45),
    ]

    enum TimerMode: String {
        case focus, shortBreak, longBreak

        var label: String {
            switch self {
            case .focus: "Focus"
            case .shortBreak: "Short Break"
            case .longBreak: "Long Break"
            }
        }
    }

    // MARK: - Internal

    private var timer: Timer?
    private var audioPlayer: AVAudioPlayer?
    private let defaults = UserDefaults.standard

    // UserDefaults keys — timer state
    private let kEndDate = "pomo_end_date"
    private let kMode = "pomo_mode"
    private let kSession = "pomo_session"
    private let kCompleted = "pomo_completed"
    private let kTotal = "pomo_total"
    private let kRunning = "pomo_running"
    private let kPaused = "pomo_paused"
    private let kRemaining = "pomo_remaining"

    // UserDefaults keys — settings
    private let kFocusDur = "pomo_focus_dur"
    private let kShortDur = "pomo_short_dur"
    private let kLongDur = "pomo_long_dur"
    private let kTotalSess = "pomo_total_sessions"
    private let kSoundOn = "pomo_sound_on"
    private let kSoundType = "pomo_sound_type"
    private let kSoundVol = "pomo_sound_vol"
    private let kHapticOn = "pomo_haptic_on"

    // MARK: - Init / Restore

    init() {
        restoreSettings()
        restoreState()
    }

    private func restoreSettings() {
        if defaults.object(forKey: kFocusDur) != nil {
            focusDuration = defaults.integer(forKey: kFocusDur)
            shortBreakDuration = defaults.integer(forKey: kShortDur)
            longBreakDuration = defaults.integer(forKey: kLongDur)
            totalSessions = max(1, defaults.integer(forKey: kTotalSess))
        }
        if defaults.object(forKey: kSoundOn) != nil {
            soundEnabled = defaults.bool(forKey: kSoundOn)
        }
        if let typeStr = defaults.string(forKey: kSoundType),
           let type = CompletionSound(rawValue: typeStr) {
            soundType = type
        }
        if defaults.object(forKey: kSoundVol) != nil {
            soundVolume = defaults.float(forKey: kSoundVol)
        }
        if defaults.object(forKey: kHapticOn) != nil {
            hapticEnabled = defaults.bool(forKey: kHapticOn)
        }
    }

    private func persistSettings() {
        defaults.set(focusDuration, forKey: kFocusDur)
        defaults.set(shortBreakDuration, forKey: kShortDur)
        defaults.set(longBreakDuration, forKey: kLongDur)
        defaults.set(totalSessions, forKey: kTotalSess)
        defaults.set(soundEnabled, forKey: kSoundOn)
        defaults.set(soundType.rawValue, forKey: kSoundType)
        defaults.set(soundVolume, forKey: kSoundVol)
        defaults.set(hapticEnabled, forKey: kHapticOn)
    }

    private func restoreState() {
        guard defaults.bool(forKey: kRunning) else {
            resetToIdle()
            return
        }

        let modeStr = defaults.string(forKey: kMode) ?? "focus"
        currentMode = TimerMode(rawValue: modeStr) ?? .focus
        currentSession = defaults.integer(forKey: kSession)
        sessionsCompleted = defaults.integer(forKey: kCompleted)
        totalSeconds = defaults.integer(forKey: kTotal)

        if defaults.bool(forKey: kPaused) {
            secondsRemaining = defaults.integer(forKey: kRemaining)
            isPaused = true
            isRunning = true
        } else if let endDate = defaults.object(forKey: kEndDate) as? Date {
            let remaining = Int(endDate.timeIntervalSinceNow)
            if remaining > 0 {
                secondsRemaining = remaining
                isRunning = true
                isPaused = false
                startTicking()
            } else {
                isRunning = false
                advanceToNextPhase()
                start()
            }
        }
    }

    // MARK: - Actions

    func start() {
        if !isRunning {
            totalSeconds = durationForMode(currentMode)
            secondsRemaining = totalSeconds
        }
        isRunning = true
        isPaused = false
        saveEndDate()
        startTicking()
        persistState()
    }

    func pause() {
        isPaused = true
        timer?.invalidate()
        timer = nil
        defaults.removeObject(forKey: kEndDate)
        defaults.set(secondsRemaining, forKey: kRemaining)
        persistState()
    }

    func resume() {
        isPaused = false
        saveEndDate()
        startTicking()
        persistState()
    }

    func reset() {
        timer?.invalidate()
        timer = nil
        clearPersistence()
        resetToIdle()
    }

    func skip() {
        timer?.invalidate()
        timer = nil
        advanceToNextPhase()
        start()
    }

    func selectMode(_ mode: TimerMode) {
        guard !isRunning else { return }
        currentMode = mode
        totalSeconds = durationForMode(mode)
        secondsRemaining = totalSeconds
    }

    func setCustomDuration(minutes: Int) {
        guard !isRunning, minutes > 0 else { return }
        switch currentMode {
        case .focus: focusDuration = minutes * 60
        case .shortBreak: shortBreakDuration = minutes * 60
        case .longBreak: longBreakDuration = minutes * 60
        }
        totalSeconds = minutes * 60
        secondsRemaining = minutes * 60
    }

    func applyPreset(_ preset: (label: String, focus: Int, short: Int, long: Int)) {
        guard !isRunning else { return }
        focusDuration = preset.focus * 60
        shortBreakDuration = preset.short * 60
        longBreakDuration = preset.long * 60
        totalSeconds = durationForMode(currentMode)
        secondsRemaining = totalSeconds
    }

    // MARK: - Sound & Haptic

    func playCompletionFeedback() {
        #if os(iOS)
        if hapticEnabled {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
        #endif
        if soundEnabled {
            playSound(soundType)
        }
    }

    /// Play a sound — used for completion and preview in settings.
    func playSound(_ sound: CompletionSound) {
        guard FileManager.default.fileExists(atPath: sound.filePath) else {
            AudioServicesPlaySystemSound(1005)
            return
        }
        let url = URL(fileURLWithPath: sound.filePath)
        do {
            #if os(iOS)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = soundVolume
            audioPlayer?.play()
        } catch {
            AudioServicesPlaySystemSound(1005)
        }
    }

    // MARK: - Computed

    var progress: Double {
        guard totalSeconds > 0 else { return 1.0 }
        return Double(secondsRemaining) / Double(totalSeconds)
    }

    var timeString: String {
        let m = secondsRemaining / 60
        let s = secondsRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

    var isBreak: Bool {
        currentMode == .shortBreak || currentMode == .longBreak
    }

    // MARK: - Private

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.tick()
            }
        }
    }

    private func tick() {
        if secondsRemaining > 0 {
            secondsRemaining -= 1
        } else {
            timer?.invalidate()
            timer = nil
            onPhaseComplete()
        }
    }

    private func onPhaseComplete() {
        playCompletionFeedback()
        if currentMode == .focus {
            sessionsCompleted += 1
        }
        advanceToNextPhase()
        start()
    }

    private func advanceToNextPhase() {
        switch currentMode {
        case .focus:
            if sessionsCompleted >= totalSessions {
                currentMode = .longBreak
                sessionsCompleted = 0
                currentSession = 1
            } else {
                currentMode = .shortBreak
            }
        case .shortBreak:
            currentMode = .focus
            currentSession = sessionsCompleted + 1
        case .longBreak:
            currentMode = .focus
            currentSession = 1
            sessionsCompleted = 0
        }
        isRunning = false
    }

    private func durationForMode(_ mode: TimerMode) -> Int {
        switch mode {
        case .focus: focusDuration
        case .shortBreak: shortBreakDuration
        case .longBreak: longBreakDuration
        }
    }

    private func resetToIdle() {
        isRunning = false
        isPaused = false
        currentMode = .focus
        currentSession = 1
        sessionsCompleted = 0
        totalSeconds = focusDuration
        secondsRemaining = focusDuration
    }

    // MARK: - Persistence

    private func saveEndDate() {
        let end = Date().addingTimeInterval(TimeInterval(secondsRemaining))
        defaults.set(end, forKey: kEndDate)
    }

    private func persistState() {
        defaults.set(isRunning, forKey: kRunning)
        defaults.set(isPaused, forKey: kPaused)
        defaults.set(currentMode.rawValue, forKey: kMode)
        defaults.set(currentSession, forKey: kSession)
        defaults.set(sessionsCompleted, forKey: kCompleted)
        defaults.set(totalSeconds, forKey: kTotal)
    }

    private func clearPersistence() {
        for key in [kEndDate, kMode, kSession, kCompleted, kTotal, kRunning, kPaused, kRemaining] {
            defaults.removeObject(forKey: key)
        }
    }
}
