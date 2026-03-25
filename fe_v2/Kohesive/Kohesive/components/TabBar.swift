import SwiftUI

enum AppTab: Int, CaseIterable {
    case home, tools, leah, profile

    var label: String {
        switch self {
        case .home: "Hub"
        case .tools: "Tools"
        case .leah: "Leah"
        case .profile: "You"
        }
    }

    var icon: String {
        switch self {
        case .home: "circle.fill"
        case .tools: "hammer.fill"
        case .leah: "bubble.left.and.bubble.right.fill"
        case .profile: "person.crop.circle"
        }
    }
}

/// Bottom navigation bar matching the HTML .bottom-nav
struct MoltenTabBar: View {
    @Binding var selected: AppTab

    var body: some View {
        HStack {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(0.5)
                    }
                    .foregroundStyle(
                        selected == tab ? Molten.Accent.primary : Molten.Text.tertiary
                    )
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 30)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: 0x1A1118, opacity: 0.9),
                    Color.clear
                ],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
}

// MARK: - Tab Bar Visibility

/// Preference key to hide the tab bar from child views
struct HideTabBarKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func hidesTabBar(_ hidden: Bool = true) -> some View {
        preference(key: HideTabBarKey.self, value: hidden)
    }
}

/// Main tab container
struct MainTabView: View {
    @Environment(AuthService.self) private var auth
    @State private var selectedTab: AppTab = .home
    @State private var tabBarHidden = false
    @State private var showLogin = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content (each view owns its own BlobBackground)
            TabContent(selectedTab: selectedTab)

            // Guest sign-in banner (above tab bar)
            if !auth.isLoggedIn && !tabBarHidden {
                GuestBanner { showLogin = true }
                    .padding(.bottom, 68)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Tab bar
            if !tabBarHidden {
                MoltenTabBar(selected: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: tabBarHidden)
        .animation(.easeInOut(duration: 0.3), value: auth.isLoggedIn)
        .onPreferenceChange(HideTabBarKey.self) { tabBarHidden = $0 }
        .sheet(isPresented: $showLogin) {
            LoginSheet()
                .environment(auth)
        }
    }
}

// MARK: - Guest Sign-In Banner

struct GuestBanner: View {
    let onSignIn: () -> Void

    var body: some View {
        Button(action: onSignIn) {
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 15))
                    .foregroundStyle(Molten.Accent.primary)

                Text("Sign in to sync your data")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Molten.Text.primary)

                Spacer()

                Text("Sign In")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Molten.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Molten.Accent.primary)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Molten.Card.bg)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Molten.Accent.primary.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Molten.Shadow.deep, radius: 12, y: 6)
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }
}

struct TabContent: View {
    let selectedTab: AppTab

    var body: some View {
        switch selectedTab {
        case .home:
            HubView()
        case .tools:
            ToolsView()
        case .leah:
            NavigationStack {
                ChatView()
            }
        case .profile:
            AccountView()
        }
    }
}
