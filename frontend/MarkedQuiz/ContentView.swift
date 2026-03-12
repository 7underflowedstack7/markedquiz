import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            CRT.bgDeep.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label(
                            String(localized: "Library"),
                            systemImage: "book.fill"
                        )
                    }
                    .tag(0)

                DatabaseView()
                    .tabItem {
                        Label(
                            String(localized: "Database"),
                            systemImage: "externaldrive.fill"
                        )
                    }
                    .tag(1)

                StatsView()
                    .tabItem {
                        Label(
                            String(localized: "Stats"),
                            systemImage: "chart.bar.fill"
                        )
                    }
                    .tag(2)
            }
            .tint(CRT.orangeBright)
        }
    }
}
