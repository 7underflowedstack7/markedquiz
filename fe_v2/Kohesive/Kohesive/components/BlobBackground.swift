import SwiftUI
import UIKit

// MARK: - Keyframe Definition

private struct BlobWaypoint {
    let t: CGFloat    // normalized time 0...1
    let x: CGFloat    // translation X (points)
    let y: CGFloat    // translation Y (points)
    let s: CGFloat    // scale multiplier
    let r: CGFloat    // rotation degrees
}

// MARK: - Interpolation

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

/// Cubic ease-in-out matching CSS cubic-bezier(0.45, 0.05, 0.55, 0.95)
private func easeInOut(_ t: CGFloat) -> CGFloat {
    if t < 0.5 {
        return 2 * t * t * (1.5 - t)
    } else {
        let u = 1 - t
        return 1 - 2 * u * u * (1.5 - u)
    }
}

private func interpolate(waypoints: [BlobWaypoint], at normalizedTime: CGFloat) -> (x: CGFloat, y: CGFloat, scale: CGFloat, rotation: CGFloat) {
    let t = normalizedTime.truncatingRemainder(dividingBy: 1.0)

    // Find surrounding keyframes
    var lower = waypoints.first!
    var upper = waypoints.last!

    for i in 0..<waypoints.count - 1 {
        if t >= waypoints[i].t && t <= waypoints[i + 1].t {
            lower = waypoints[i]
            upper = waypoints[i + 1]
            break
        }
    }

    let span = upper.t - lower.t
    let local = span > 0 ? easeInOut((t - lower.t) / span) : 0

    return (
        x: lerp(lower.x, upper.x, local),
        y: lerp(lower.y, upper.y, local),
        scale: lerp(lower.s, upper.s, local),
        rotation: lerp(lower.r, upper.r, local)
    )
}

// MARK: - Keyframe Paths (ported from HTML blob1Move / blob2Move)

/// Rose blob — 14s cycle, wide clockwise wander
private let roseWaypoints: [BlobWaypoint] = [
    .init(t: 0.00, x: 0,    y: 0,    s: 1.0,  r: 0),
    .init(t: 0.15, x: 120,  y: 60,   s: 1.15, r: 30),
    .init(t: 0.30, x: 80,   y: 180,  s: 0.9,  r: 80),
    .init(t: 0.45, x: 200,  y: 120,  s: 1.2,  r: 140),
    .init(t: 0.60, x: 140,  y: 280,  s: 0.85, r: 200),
    .init(t: 0.75, x: 40,   y: 200,  s: 1.1,  r: 280),
    .init(t: 0.88, x: -30,  y: 100,  s: 1.05, r: 330),
    .init(t: 1.00, x: 0,    y: 0,    s: 1.0,  r: 360),
]

/// Sand blob — 18s cycle, counter-clockwise wander
private let sandWaypoints: [BlobWaypoint] = [
    .init(t: 0.00, x: 0,    y: 0,    s: 1.0,  r: 0),
    .init(t: 0.12, x: -100, y: -80,  s: 1.2,  r: -40),
    .init(t: 0.28, x: -180, y: -30,  s: 0.85, r: -100),
    .init(t: 0.42, x: -60,  y: -200, s: 1.15, r: -160),
    .init(t: 0.55, x: -200, y: -160, s: 0.9,  r: -220),
    .init(t: 0.70, x: -120, y: -60,  s: 1.1,  r: -290),
    .init(t: 0.85, x: -40,  y: -120, s: 1.05, r: -340),
    .init(t: 1.00, x: 0,    y: 0,    s: 1.0,  r: -360),
]

/// Deep ember blob — 22s cycle, slow diagonal drift
private let deepEmberWaypoints: [BlobWaypoint] = [
    .init(t: 0.00, x: 0,    y: 0,    s: 1.0,  r: 0),
    .init(t: 0.14, x: 60,   y: -120, s: 1.1,  r: 20),
    .init(t: 0.28, x: -80,  y: -60,  s: 0.9,  r: 55),
    .init(t: 0.42, x: 140,  y: -180, s: 1.2,  r: 100),
    .init(t: 0.56, x: -40,  y: 100,  s: 0.85, r: 155),
    .init(t: 0.70, x: 100,  y: 60,   s: 1.15, r: 220),
    .init(t: 0.85, x: -60,  y: -40,  s: 1.05, r: 300),
    .init(t: 1.00, x: 0,    y: 0,    s: 1.0,  r: 360),
]

// MARK: - Blob Colors (17% brighter than theme tokens)

private enum BlobColor {
    // Ember _500 #C4582A → +17% → #E56731
    static let rose = Color(hex: 0xE56731)
    // Ember _900 #6B2D0A → +17% → #7D350C
    static let roseDeep = Color(hex: 0x7D350C)
    // Sand _500 #C6A27A → +17% → #E8BE8F
    static let sand = Color(hex: 0xE8BE8F)
    // Sand _700 #6B5B4D → +17% → #7D6A5A
    static let sandDeep = Color(hex: 0x7D6A5A)
    // Deep ember — warm midtone between rose and sand
    static let deepEmber = Color(hex: 0xD4764A)
    static let deepEmberCore = Color(hex: 0x8A3F1A)
}

// MARK: - Cycle Durations

private let roseCycle: TimeInterval = 14
private let sandCycle: TimeInterval = 18
private let deepEmberCycle: TimeInterval = 22
private let pulseCycle: TimeInterval = 4

// MARK: - BlobBackground View

/// Animated triple-blob background with keyframe-driven paths,
/// scale breathing, rotation, and inner pulse layers.
/// Pauses animation when keyboard is visible to avoid GPU contention.
struct BlobBackground: View {
    @State private var startDate = Date()
    @State private var keyboardVisible = false
    @State private var frozenElapsed: TimeInterval = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0)) { timeline in
            let elapsed = keyboardVisible ? frozenElapsed : timeline.date.timeIntervalSince(startDate)

            GeometryReader { geo in
                let roseT = CGFloat(elapsed.truncatingRemainder(dividingBy: roseCycle)) / CGFloat(roseCycle)
                let sandT = CGFloat(elapsed.truncatingRemainder(dividingBy: sandCycle)) / CGFloat(sandCycle)
                let deepT = CGFloat(elapsed.truncatingRemainder(dividingBy: deepEmberCycle)) / CGFloat(deepEmberCycle)
                let pulseT = CGFloat(elapsed.truncatingRemainder(dividingBy: pulseCycle)) / CGFloat(pulseCycle)

                let rose = interpolate(waypoints: roseWaypoints, at: roseT)
                let sand = interpolate(waypoints: sandWaypoints, at: sandT)
                let deep = interpolate(waypoints: deepEmberWaypoints, at: deepT)

                // Pulse: scale 0.9→1.1, opacity 0.3→0.5 over 4s alternating
                let pulseScale = 0.9 + 0.2 * (0.5 + 0.5 * cos(pulseT * .pi * 2))
                let pulseOpacity = 0.3 + 0.2 * (0.5 + 0.5 * cos(pulseT * .pi * 2))

                let cx = geo.size.width * 0.5
                let cy = geo.size.height * 0.5

                ZStack {
                    // Base
                    Molten.BG.deep
                        .ignoresSafeArea()

                    // ---- Blob 1: Rose (top-left origin) ----
                    ZStack {
                        // Inner pulse layer
                        Circle()
                            .fill(roseGradient)
                            .frame(width: 336, height: 336)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .blur(radius: 35)

                        // Main blob
                        Circle()
                            .fill(roseGradient)
                            .frame(width: 280, height: 280)
                    }
                    .blur(radius: 70)
                    .scaleEffect(rose.scale)
                    .rotationEffect(.degrees(rose.rotation))
                    .offset(
                        x: -cx * 0.3 + rose.x * 0.55,
                        y: -cy * 0.25 + rose.y * 0.45
                    )
                    .blendMode(.screen)

                    // ---- Blob 2: Sand (bottom-right origin) ----
                    ZStack {
                        // Inner pulse layer
                        Circle()
                            .fill(sandGradient)
                            .frame(width: 288, height: 288)
                            .scaleEffect(pulseScale)
                            .opacity(pulseOpacity)
                            .blur(radius: 35)

                        // Main blob
                        Circle()
                            .fill(sandGradient)
                            .frame(width: 240, height: 240)
                    }
                    .blur(radius: 70)
                    .scaleEffect(sand.scale)
                    .rotationEffect(.degrees(sand.rotation))
                    .offset(
                        x: cx * 0.25 + sand.x * 0.5,
                        y: cy * 0.3 + sand.y * 0.4
                    )
                    .blendMode(.screen)

                    // ---- Blob 3: Deep Ember (center-top, slow drifter) ----
                    ZStack {
                        Circle()
                            .fill(deepEmberGradient)
                            .frame(width: 320, height: 320)
                            .scaleEffect(pulseScale * 0.95)
                            .opacity(pulseOpacity * 0.8)
                            .blur(radius: 44)

                        Circle()
                            .fill(deepEmberGradient)
                            .frame(width: 200, height: 200)
                    }
                    .blur(radius: 79)
                    .scaleEffect(deep.scale)
                    .rotationEffect(.degrees(deep.rotation))
                    .offset(
                        x: deep.x * 0.45,
                        y: -cy * 0.15 + deep.y * 0.4
                    )
                    .blendMode(.screen)
                    .opacity(0.55)

                    // Grain overlay
                    GrainOverlay()
                }
                .drawingGroup()
            }
        }
        .ignoresSafeArea()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            frozenElapsed = Date().timeIntervalSince(startDate)
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            // Adjust startDate so animation resumes smoothly from where it froze
            startDate = Date().addingTimeInterval(-frozenElapsed)
            keyboardVisible = false
        }
    }

    // MARK: - Gradients

    private var roseGradient: RadialGradient {
        RadialGradient(
            colors: [
                BlobColor.rose.opacity(0.88),
                BlobColor.roseDeep.opacity(0.7),
                Color.clear
            ],
            center: UnitPoint(x: 0.4, y: 0.4),
            startRadius: 0,
            endRadius: 140
        )
    }

    private var sandGradient: RadialGradient {
        RadialGradient(
            colors: [
                BlobColor.sand.opacity(0.82),
                BlobColor.sandDeep.opacity(0.65),
                Color.clear
            ],
            center: UnitPoint(x: 0.6, y: 0.6),
            startRadius: 0,
            endRadius: 120
        )
    }

    private var deepEmberGradient: RadialGradient {
        RadialGradient(
            colors: [
                BlobColor.deepEmber.opacity(0.7),
                BlobColor.deepEmberCore.opacity(0.5),
                Color.clear
            ],
            center: UnitPoint(x: 0.5, y: 0.45),
            startRadius: 0,
            endRadius: 160
        )
    }
}

// MARK: - Grain Overlay

/// Subtle noise grain texture overlay — static dots generated once
struct GrainOverlay: View {
    private struct Dot {
        let x: CGFloat
        let y: CGFloat
        let opacity: Double
    }

    // Generate dots once at init, not every frame
    private let dots: [Dot] = (0..<600).map { _ in
        Dot(
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            opacity: Double.random(in: 0.01...0.04)
        )
    }

    var body: some View {
        Canvas { context, size in
            for dot in dots {
                let rect = CGRect(
                    x: dot.x * size.width,
                    y: dot.y * size.height,
                    width: 1.5, height: 1.5
                )
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(.white.opacity(dot.opacity))
                )
            }
        }
        .allowsHitTesting(false)
        .blendMode(.overlay)
    }
}
