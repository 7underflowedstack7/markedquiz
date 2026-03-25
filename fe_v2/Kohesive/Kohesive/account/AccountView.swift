import SwiftUI

/// View 3: Profile / Account — minimal: guest header + sign in
struct AccountView: View {
    @Environment(AuthService.self) private var auth
    @State private var showLogin = false
    @State private var showTailscale = false

    var body: some View {
        NavigationStack {
        ZStack {
            BlobBackground()
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // Profile header
                VStack(spacing: 0) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Molten.Text.secondary)
                        .frame(width: 88, height: 88)
                        .background(
                            Circle()
                                .fill(.ultraThinMaterial)
                                .overlay(Circle().fill(Molten.Card.bg))
                        )
                        .overlay(
                            Circle().stroke(Molten.Card.border, lineWidth: 2)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 12, y: 4)
                        .padding(.bottom, 14)

                    Text(displayName)
                        .font(.custom("Georgia", size: 26))
                        .foregroundStyle(Molten.Text.primary)
                        .padding(.bottom, 4)

                    Text(auth.currentUser?.email ?? "Not signed in")
                        .font(.moltenCaption())
                        .foregroundStyle(Molten.Text.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)
                .padding(.top, 10)

                // Tailscale button
                NavigationLink(destination: TailscaleSettingsView()) {
                    HStack(spacing: 14) {
                        Image(systemName: "network")
                            .font(.system(size: 16))
                            .frame(width: 34, height: 34)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                            )
                            .foregroundStyle(Molten.Text.primary)

                        Text("Tailscale")
                            .font(.moltenBody(14))
                            .foregroundStyle(Molten.Text.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(Molten.Text.tertiary)
                    }
                    .settingsRow()
                }
                .padding(.bottom, 14)

                // Sign out / Sign in
                if auth.isLoggedIn {
                    Button(action: { auth.logout() }) {
                        Text("Sign Out")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(0.5)
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
                    .padding(.top, 20)
                } else {
                    Button(action: { showLogin = true }) {
                        Text("Sign In")
                            .font(.system(size: 14, weight: .medium))
                            .tracking(0.5)
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
                    .padding(.top, 20)
                    .sheet(isPresented: $showLogin) {
                        LoginSheet()
                            .environment(auth)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 60)
            .padding(.bottom, 100)
        }
        .onAppear {
            if auth.isLoggedIn && auth.currentUser == nil {
                Task { await auth.fetchMe() }
            }
        }
        } // ZStack
        } // NavigationStack
    }

    private var displayName: String {
        if let email = auth.currentUser?.email {
            return email.components(separatedBy: "@").first?.capitalized ?? "User"
        }
        return "Guest"
    }
}

// MARK: - Login Sheet

struct LoginSheet: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isRegister = false

    var body: some View {
        ZStack {
            Molten.BG.deep.ignoresSafeArea()

            VStack(spacing: 24) {
                Text(isRegister ? "Create Account" : "Sign In")
                    .font(.moltenTitle())
                    .foregroundStyle(Molten.Text.primary)
                    .padding(.top, 40)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .font(.moltenBody())
                        .foregroundStyle(Molten.Text.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Molten.Card.bg)
                        )
                        .overlay(
                            Capsule().stroke(Molten.Card.border, lineWidth: 1)
                        )

                    SecureField("Password", text: $password)
                        .font(.moltenBody())
                        .foregroundStyle(Molten.Text.primary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                        .background(
                            Capsule().fill(Molten.Card.bg)
                        )
                        .overlay(
                            Capsule().stroke(Molten.Card.border, lineWidth: 1)
                        )
                }

                if let error = auth.error {
                    Text(error)
                        .font(.moltenSmall())
                        .foregroundStyle(Color.red.opacity(0.8))
                }

                Button(action: submit) {
                    Group {
                        if auth.isLoading {
                            ProgressView()
                                .tint(Molten.Text.primary)
                        } else {
                            Text(isRegister ? "Register" : "Sign In")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .foregroundStyle(Molten.Text.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(Molten.Accent.primary)
                    )
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                    .shadow(color: Molten.Shadow.fab, radius: 12, y: 6)
                }
                .disabled(email.isEmpty || password.isEmpty || auth.isLoading)

                Button(action: { isRegister.toggle() }) {
                    Text(isRegister ? "Already have an account? Sign In" : "Don't have an account? Register")
                        .font(.moltenCaption())
                        .foregroundStyle(Molten.Text.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: auth.isLoggedIn) { _, loggedIn in
            if loggedIn { dismiss() }
        }
    }

    private func submit() {
        Task {
            if isRegister {
                await auth.register(email: email, password: password)
            } else {
                await auth.login(email: email, password: password)
            }
        }
    }
}
