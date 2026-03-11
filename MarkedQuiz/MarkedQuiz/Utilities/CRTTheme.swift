import SwiftUI

enum CRT {
    // Primary phosphor colors
    static let orangeBright = Color(red: 1.0, green: 0.549, blue: 0.0)       // #FF8C00
    static let orangeHot = Color(red: 1.0, green: 0.416, blue: 0.0)          // #FF6A00
    static let orangeGlow = Color(red: 1.0, green: 0.667, blue: 0.2)         // #FFAA33
    static let orangeDim = Color(red: 0.702, green: 0.349, blue: 0.0)        // #B35900
    static let orangeFaint = Color(red: 0.4, green: 0.2, blue: 0.0)          // #663300

    // Accent colors
    static let amber = Color(red: 1.0, green: 0.749, blue: 0.0)              // #FFBF00
    static let cyanAccent = Color(red: 0.0, green: 0.8, blue: 0.667)         // #00CCAA
    static let redAccent = Color(red: 1.0, green: 0.2, blue: 0.2)            // #FF3333
    static let greenAccent = Color(red: 0.2, green: 1.0, blue: 0.4)          // #33FF66

    // Backgrounds
    static let bgDeep = Color(red: 0.039, green: 0.039, blue: 0.031)         // #0A0A08
    static let bgPanel = Color(red: 0.067, green: 0.067, blue: 0.063)        // #111110
    static let bgLine = Color(red: 0.102, green: 0.102, blue: 0.086)         // #1A1A16

    // Text
    static let textDim = Color(red: 0.353, green: 0.333, blue: 0.251)        // #5A5540
    static let textGhost = Color(red: 0.227, green: 0.208, blue: 0.188)      // #3A3530

    // Glow
    static let phosphorGlow = Color(red: 1.0, green: 0.549, blue: 0.0).opacity(0.15)

    // Fonts
    static let monoFont = "Menlo"
    static let monoFontBold = "Menlo-Bold"

    static func monoText(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    static func monoBold(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

// MARK: - View Modifiers

struct CRTGlowModifier: ViewModifier {
    var color: Color = CRT.orangeBright
    var radius: CGFloat = 4

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}

struct CRTPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(CRT.bgPanel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(CRT.orangeFaint, lineWidth: 1)
            )
    }
}

struct ScanlinesOverlay: View {
    var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                for y in stride(from: 0.0, to: size.height, by: 4) {
                    let rect = CGRect(x: 0, y: y + 2, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.08)))
                }
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    func crtGlow(color: Color = CRT.orangeBright, radius: CGFloat = 4) -> some View {
        modifier(CRTGlowModifier(color: color, radius: radius))
    }

    func crtPanel() -> some View {
        modifier(CRTPanelModifier())
    }
}
