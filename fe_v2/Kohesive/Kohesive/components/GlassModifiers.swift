import SwiftUI

// MARK: - Glass Card Modifier
/// Matches .glass-card from HTML: frosted background, border, shadow
/// Uses ultraThinMaterial (lighter GPU cost than thinMaterial)

struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = Molten.Radius.xl
    var padding: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 24)
            .padding(.vertical, padding)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius)
                            .fill(Molten.Card.bg)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Molten.Card.border, lineWidth: 1)
            )
            .shadow(color: Molten.Shadow.deep, radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Glass Card Small Modifier
/// Matches .glass-card-sm — no material blur, just tinted fill for performance

struct GlassCardSmallModifier: ViewModifier {
    var radius: CGFloat = Molten.Radius.md

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(Molten.Card.bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Molten.Card.border, lineWidth: 1)
            )
    }
}

// MARK: - Glass Search Bar Modifier
/// Matches .glass-search

struct GlassSearchModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Molten.Card.bg))
            )
            .overlay(
                Capsule().stroke(Molten.Card.border, lineWidth: 1)
            )
            .shadow(color: Molten.Shadow.deep, radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Glass Pill Modifier
/// Matches .glass-pill — no material, just solid tinted fill

struct GlassPillModifier: ViewModifier {
    var isAccent: Bool = false

    func body(content: Content) -> some View {
        content
            .font(.moltenSmall())
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(isAccent ? Molten.Accent.primary.opacity(0.138) : Color.white.opacity(0.058))
            )
            .overlay(
                Capsule()
                    .stroke(
                        isAccent ? Molten.Accent.primary.opacity(0.23) : Color.white.opacity(0.115),
                        lineWidth: 1
                    )
            )
            .foregroundStyle(isAccent ? Molten.Accent.primary : Molten.Text.secondary)
    }
}

// MARK: - Settings Row Modifier
/// Matches .settings-row

struct SettingsRowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(Molten.Card.bg))
            )
            .overlay(
                Capsule().stroke(Molten.Card.border, lineWidth: 1)
            )
            .shadow(color: Molten.Shadow.deep, radius: 16, x: 0, y: 8)
            .shadow(color: Color.black.opacity(0.25), radius: 5, x: 0, y: 2)
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(radius: CGFloat = Molten.Radius.xl, padding: CGFloat = 20) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }

    func glassCardSmall(radius: CGFloat = Molten.Radius.md) -> some View {
        modifier(GlassCardSmallModifier(radius: radius))
    }

    func glassSearch() -> some View {
        modifier(GlassSearchModifier())
    }

    func glassPill(accent: Bool = false) -> some View {
        modifier(GlassPillModifier(isAccent: accent))
    }

    func settingsRow() -> some View {
        modifier(SettingsRowModifier())
    }
}
