import SwiftUI

/// Tools hub — navigation to Records, Habits, Quizzes
struct ToolsView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BlobBackground()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Tools")
                        .font(.moltenTitle())
                        .foregroundStyle(Molten.Text.primary)
                        .padding(.bottom, 8)

                    ToolCard(icon: "list.bullet.rectangle", title: "Records", subtitle: "Browse your files and notes") {
                        path.append(ToolRoute.records)
                    }
                    ToolCard(icon: "checkmark.circle", title: "Habits", subtitle: "Track daily habits") {
                        path.append(ToolRoute.habits)
                    }
                    ToolCard(icon: "questionmark.circle", title: "Quizzes", subtitle: "Test your knowledge") {
                        path.append(ToolRoute.quizzes)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 60)
                .padding(.bottom, 100)
            }
            } // ZStack
            .navigationDestination(for: ToolRoute.self) { route in
                switch route {
                case .records: RecordsView()
                case .habits: HabitsFullView()
                case .quizzes: QuizzesView()
                }
            }
        }
    }
}

enum ToolRoute: Hashable {
    case records, habits, quizzes
}

struct ToolCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Molten.Accent.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Molten.Accent.primary.opacity(0.12))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Molten.Text.primary)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Molten.Text.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(Molten.Text.tertiary)
            }
            .glassCard(radius: Molten.Radius.xl, padding: 16)
        }
        .buttonStyle(.plain)
    }
}
