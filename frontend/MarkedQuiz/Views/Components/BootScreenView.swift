import SwiftUI

struct BootScreenView: View {
    var onBootComplete: () -> Void

    @State private var visibleLines = 0
    @State private var bootTask: Task<Void, Never>?

    private let bootLines: [(text: String, color: BootLineColor, delay: Int)] = [
        ("  ██████╗  ██████╗       ████████╗███████╗██████╗ ███╗   ███╗", .hot, 100),
        ("  ██╔══██╗██╔══██╗      ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║", .orange, 30),
        ("  ██║  ██║██████╔╝█████╗   ██║   █████╗  ██████╔╝██╔████╔██║", .orange, 30),
        ("  ██║  ██║██╔══██╗╚════╝   ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║", .amber, 30),
        ("  ██████╔╝██████╔╝         ██║   ███████╗██║  ██║██║ ╚═╝ ██║", .amber, 30),
        ("  ╚═════╝ ╚═════╝          ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝", .dim, 80),
        ("", .dim, 50),
        ("  MARKED//QUIZ Terminal v1.0 // Build 2026.03", .dim, 200),
        ("  ─────────────────────────────────────────────", .faint, 100),
        ("", .dim, 50),
        ("  BIOS  Initializing memory banks...        OK", .system, 300),
        ("  KERN  Loading kernel modules...            OK", .system, 200),
        ("  DISK  Mounting /dev/db0...                 OK", .system, 250),
        ("  NET   Establishing connection...    CONNECTED", .system, 200),
        ("  AUTH  User authenticated:        alan@mq-term", .system, 150),
        ("", .dim, 100),
        ("  ┌─ SYSTEM STATUS ─────────────────────────────┐", .cyan, 50),
        ("  │ Swift:     6.0          FastAPI:  0.115.0    │", .info, 50),
        ("  │ Platform:  iOS 18       Backend:  Render     │", .info, 50),
        ("  │ Database:  PostgreSQL   Documents: loading   │", .info, 50),
        ("  └──────────────────────────────────────────────┘", .cyan, 50),
        ("", .dim, 100),
        ("  Ready.", .dim, 50),
    ]

    var body: some View {
        ZStack {
            CRT.bgDeep.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(0..<min(visibleLines, bootLines.count), id: \.self) { i in
                        let line = bootLines[i]
                        Text(line.text)
                            .font(.system(size: 11, weight: line.color == .hot || line.color == .orange || line.color == .amber ? .bold : .regular, design: .monospaced))
                            .foregroundStyle(colorFor(line.color))
                            .shadow(color: CRT.orangeBright.opacity(0.3), radius: line.color == .hot ? 6 : 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineSpacing(0)
                            .minimumScaleFactor(0.5)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }

            ScanlinesOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .onAppear {
            bootTask = Task { @MainActor in
                for i in 0..<bootLines.count {
                    guard !Task.isCancelled else { return }
                    try? await Task.sleep(for: .milliseconds(bootLines[i].delay))
                    visibleLines = i + 1
                }
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                onBootComplete()
            }
        }
        .onDisappear {
            bootTask?.cancel()
        }
    }

    private func colorFor(_ c: BootLineColor) -> Color {
        switch c {
        case .hot: return CRT.orangeHot
        case .orange: return CRT.orangeBright
        case .amber: return CRT.amber
        case .dim: return CRT.textDim
        case .faint: return CRT.orangeFaint
        case .system: return CRT.orangeGlow
        case .cyan: return CRT.cyanAccent
        case .info: return CRT.orangeBright
        case .green: return CRT.greenAccent
        }
    }
}

private enum BootLineColor {
    case hot, orange, amber, dim, faint, system, cyan, info, green
}
