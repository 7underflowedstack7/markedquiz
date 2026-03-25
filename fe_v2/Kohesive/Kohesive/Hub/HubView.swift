import SwiftUI

/// View 1: Home / Hub — greeting + offset masonry grid of widgets
struct HubView: View {
    @Environment(AuthService.self) private var auth
    @State private var appeared = false

    var body: some View {
        ZStack {
            BlobBackground()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Greeting ──
                Text("Good evening,")
                    .font(.moltenDisplay())
                    .foregroundStyle(Molten.Text.primary)
                Text(auth.currentUser?.email.components(separatedBy: "@").first ?? "Guest")
                    .font(.moltenDisplay())
                    .foregroundStyle(Molten.Accent.primary)
                    .padding(.top, -4)
                Text(currentDateString)
                    .font(.moltenCaption())
                    .foregroundStyle(Molten.Text.secondary)
                    .padding(.bottom, 28)

                // ── Dashboard (full width, top) ──
                DashboardWidget()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .padding(.bottom, 14)

                // ── Two-column grid ──
                HStack(alignment: .top, spacing: 12) {

                    // LEFT COLUMN
                    VStack(spacing: 14) {
                        PomodoroWidget()
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                    }
                    .frame(maxWidth: .infinity)

                    // RIGHT COLUMN
                    VStack(spacing: 14) {
                        HabitsWidget()
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 20)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.bottom, 14)

                // ── Connection Dashboard (full width) ──
                ConnectionWidget()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 100)
        }
        } // ZStack
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.15)) {
                appeared = true
            }
        }
    }

    private var currentDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
}
