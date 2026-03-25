import SwiftUI

@main
struct KohesiveApp: App {
    @State private var authService = AuthService()
    @State private var pomodoroTimer = PomodoroTimer()
    @State private var habitsService = HabitsService()
    @State private var quizStatsService = QuizStatsService()
    @State private var fileService = FileService()
    @State private var remoteLLMService = RemoteLLMService()
    @State private var levelService = LevelService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authService)
                .environment(pomodoroTimer)
                .environment(habitsService)
                .environment(quizStatsService)
                .environment(fileService)
                .environment(remoteLLMService)
                .environment(levelService)
                .preferredColorScheme(.dark)
        }
    }
}

/// Root view that handles session restoration and lock screen
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @State private var hasAttemptedRestore = false

    var body: some View {
        ZStack {
            if !hasAttemptedRestore {
                // Splash / loading state while restoring session
                SplashView()
            } else if auth.hasStoredSession && !auth.isUnlocked {
                // Has a stored session but not yet unlocked — show passcode gate
                LockScreenView()
            } else if auth.isLoggedIn && auth.isUnlocked {
                // Authenticated and unlocked — full app
                MainTabView()
            } else {
                // Guest preview — show full UI with empty data
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: hasAttemptedRestore)
        .animation(.easeInOut(duration: 0.3), value: auth.isUnlocked)
        .animation(.easeInOut(duration: 0.3), value: auth.isLoggedIn)
        .task {
            // Clean up any orphaned access tokens before attempting restore
            auth.cleanupOrphanedTokens()
            if auth.hasStoredSession {
                await auth.restoreSession()
            }
            hasAttemptedRestore = true
        }
    }
}

// MARK: - Splash View (shown during session restore)

struct SplashView: View {
    var body: some View {
        ZStack {
            BlobBackground()
            VStack(spacing: 16) {
                Text("Kohesive")
                    .font(.custom("Georgia", size: 32).weight(.light))
                    .foregroundStyle(Molten.Text.primary)
                ProgressView()
                    .tint(Molten.Accent.primary)
            }
        }
    }
}

// MARK: - Lock Screen (passcode gate)

struct LockScreenView: View {
    @Environment(AuthService.self) private var auth
    @State private var isAuthenticating = false
    @State private var authFailed = false

    var body: some View {
        ZStack {
            BlobBackground()

            VStack(spacing: 24) {
                Spacer()

                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Molten.Accent.primary)

                Text("Kohesive")
                    .font(.custom("Georgia", size: 28).weight(.light))
                    .foregroundStyle(Molten.Text.primary)

                if let email = auth.currentUser?.email {
                    Text(email)
                        .font(.moltenCaption())
                        .foregroundStyle(Molten.Text.tertiary)
                }

                if authFailed {
                    Text("Authentication failed. Try again.")
                        .font(.moltenSmall())
                        .foregroundStyle(Color.red.opacity(0.8))
                }

                Spacer()

                // Unlock button
                Button(action: unlock) {
                    HStack(spacing: 10) {
                        if isAuthenticating {
                            ProgressView()
                                .tint(Molten.Text.primary)
                        } else {
                            Image(systemName: "lock.open")
                                .font(.system(size: 16))
                            Text("Unlock with Passcode")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .foregroundStyle(Molten.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule().fill(Molten.Accent.primary)
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 12, y: 6)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 40)

                // Sign out option
                Button(action: { auth.logout() }) {
                    Text("Sign Out")
                        .font(.moltenCaption())
                        .foregroundStyle(Molten.Text.tertiary)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Auto-prompt passcode on appear
            unlock()
        }
    }

    private func unlock() {
        isAuthenticating = true
        authFailed = false
        Task {
            let success = await auth.authenticateWithPasscode()
            isAuthenticating = false
            if !success {
                authFailed = true
            }
        }
    }
}
