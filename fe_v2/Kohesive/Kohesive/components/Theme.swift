import SwiftUI

// MARK: - Molten Earth Theme
// Exact port of theme_iteration_1.html "Molten Earth" design system

enum Molten {

    // MARK: - Core Palette

    enum Base {
        static let _950 = Color(hex: 0x0D0907)
        static let _900 = Color(hex: 0x160D09)
        static let _800 = Color(hex: 0x221712)
    }

    enum Ember {
        static let _900 = Color(hex: 0x6B2D0A)
        static let _500 = Color(hex: 0xC4582A)
        static let _400 = Color(hex: 0x8B3A15)
    }

    enum Sand {
        static let _700 = Color(hex: 0x6B5B4D)
        static let _500 = Color(hex: 0xC6A27A)
    }

    enum Cream {
        static let pure = Color(hex: 0xF5ECDD)
    }

    // MARK: - Semantic Tokens

    enum BG {
        static let primary = Base._800
        static let deep = Base._900
    }

    enum Card {
        static let bg = Color.white.opacity(0.092)
        static let bgHover = Color.white.opacity(0.138)
        static let border = Color.white.opacity(0.173)
        static let borderHover = Color.white.opacity(0.253)
        static let highlight = Color.white.opacity(0.138)
    }

    enum Glass {
        static let bg = Color.white.opacity(0.063)
        static let bgHover = Color.white.opacity(0.104)
        static let border = Color.white.opacity(0.138)
        static let borderStrong = Color.white.opacity(0.207)
    }

    enum Text {
        static let primary = Cream.pure
        static let secondary = Cream.pure.opacity(0.55)
        static let tertiary = Cream.pure.opacity(0.35)
    }

    enum Accent {
        static let primary = Ember._500       // #C4582A
        static let primarySoft = Ember._500.opacity(0.3)
        static let warm = Sand._500           // #c6a27a
    }

    // MARK: - Spacing

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let base: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 40
    }

    // MARK: - Radius (pill-based)

    enum Radius {
        static let sm: CGFloat = 14
        static let md: CGFloat = 20
        static let lg: CGFloat = 26
        static let xl: CGFloat = 30
        static let full: CGFloat = 100
    }

    // MARK: - Blur

    static let blur: CGFloat = 20

    // MARK: - Shadows

    enum Shadow {
        static let card = Color.black.opacity(0.25)
        static let cardHover = Color.black.opacity(0.35)
        static let deep = Color.black.opacity(0.4)
        static let fab = Color(hex: 0xC4582A).opacity(0.35)
    }
}

// MARK: - Font Extensions

extension Font {
    /// Display serif — Cormorant Garamond equivalent (Georgia)
    static func moltenDisplay(_ size: CGFloat = 32) -> Font {
        .custom("Georgia", size: size).weight(.light)
    }

    /// Title serif
    static func moltenTitle(_ size: CGFloat = 28) -> Font {
        .custom("Georgia", size: size).weight(.regular)
    }

    /// Body sans — DM Sans equivalent (system)
    static func moltenBody(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular)
    }

    /// Caption sans
    static func moltenCaption(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Small label
    static func moltenSmall(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium)
    }

    /// Stat number — large serif
    static func moltenStat(_ size: CGFloat = 36) -> Font {
        .custom("Georgia", size: size).weight(.regular)
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
