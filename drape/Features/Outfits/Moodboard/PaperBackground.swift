//
//  PaperBackground.swift
//  drape
//
//  The tactile paper layer the Moodboard collage sits on. Fully procedural (no
//  asset, renders inside `ImageRenderer` for export) and unmistakably "paper":
//  a warm base, large soft mottle, two-pass grain, fibers, an upper sheen and a
//  warm vignette.
//
//  Colors are chosen from the explicit color scheme — NOT via dynamic
//  (`Theme.adaptive`) colors — because `Canvas`/`GraphicsContext` resolves
//  dynamic colors against the light trait, which made the texture invisible in
//  dark mode in-app while still rendering in exports.
//

import SwiftUI

struct PaperBackground: View {
    var seed: UInt64 = 0x5eed_1234

    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    private var baseTop: Color { isDark ? Color(hex: "262019") : Color(hex: "F3ECDE") }
    private var baseBottom: Color { isDark ? Color(hex: "1A1611") : Color(hex: "E6DAC6") }
    private var mottle: Color { isDark ? Color(hex: "4A3D2C") : Color(hex: "C9B48F") }
    private var sheen: Color { isDark ? Color(hex: "5A4F3E") : Color(hex: "FFFBF2") }
    private var darkSpeck: Color { isDark ? Color(hex: "0E0B07") : Color(hex: "5E4B33") }
    private var lightSpeck: Color { isDark ? Color(hex: "C9BCA6") : Color(hex: "FFFFFF") }
    private var vignette: Color { isDark ? Color.black : Color(hex: "241A12") }

    var body: some View {
        ZStack {
            LinearGradient(colors: [baseTop, baseBottom],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            Canvas { context, size in
                drawMottle(&context, size)
                drawGrain(&context, size)
                drawFibers(&context, size)
            }

            // Soft paper sheen, upper-centre.
            RadialGradient(colors: [sheen.opacity(isDark ? 0.22 : 0.35), .clear],
                           center: .init(x: 0.5, y: 0.26), startRadius: 0, endRadius: 360)
                .blendMode(.softLight)

            // Warm vignette to settle the edges.
            RadialGradient(colors: [.clear, vignette.opacity(isDark ? 0.30 : 0.16)],
                           center: .center, startRadius: 80, endRadius: 620)
        }
    }

    /// A handful of big, very soft warm blobs → tactile unevenness, not flat fill.
    private func drawMottle(_ context: inout GraphicsContext, _ size: CGSize) {
        var rng = SystemlessRandom(seed: seed)
        let maxDim = max(size.width, size.height)
        let alphaBoost = isDark ? 1.6 : 1.0
        for _ in 0..<7 {
            let cx = rng.unit() * size.width
            let cy = rng.unit() * size.height
            let r = (0.25 + rng.unit() * 0.35) * maxDim
            let alpha = (0.05 + rng.unit() * 0.06) * alphaBoost
            let rect = CGRect(x: cx - r, y: cy - r, width: 2 * r, height: 2 * r)
            context.fill(Path(ellipseIn: rect),
                         with: .radialGradient(Gradient(colors: [mottle.opacity(alpha), .clear]),
                                               center: CGPoint(x: cx, y: cy),
                                               startRadius: 0, endRadius: r))
        }
    }

    /// Dark fibers + light flecks, dense and large enough to read on a big board.
    private func drawGrain(_ context: inout GraphicsContext, _ size: CGSize) {
        let area = Int(size.width * size.height)
        let count = min(max(600, area / 1000 * 60), 14000)

        var rng = SystemlessRandom(seed: seed &+ 99)
        for _ in 0..<count {
            let x = rng.unit() * size.width
            let y = rng.unit() * size.height
            let r = 0.5 + rng.unit() * 1.1
            let alpha = (isDark ? 0.05 : 0.06) + rng.unit() * (isDark ? 0.07 : 0.10)
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(darkSpeck.opacity(alpha)))
        }

        var rng2 = SystemlessRandom(seed: seed &* 6364136223846793005 &+ 1)
        for _ in 0..<(count / 2) {
            let x = rng2.unit() * size.width
            let y = rng2.unit() * size.height
            let r = 0.5 + rng2.unit() * 0.9
            let alpha = (isDark ? 0.06 : 0.05) + rng2.unit() * 0.08
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                         with: .color(lightSpeck.opacity(alpha)))
        }
    }

    /// Occasional thin, mostly-horizontal paper fibers.
    private func drawFibers(_ context: inout GraphicsContext, _ size: CGSize) {
        let area = Int(size.width * size.height)
        let fibers = min(max(20, area / 40000), 120)
        var rng = SystemlessRandom(seed: seed &+ 7)
        for _ in 0..<fibers {
            let x = rng.unit() * size.width
            let y = rng.unit() * size.height
            let len = 6 + rng.unit() * 22
            let ang = (rng.unit() - 0.5) * 0.6
            var p = Path()
            p.move(to: CGPoint(x: x, y: y))
            p.addLine(to: CGPoint(x: x + cos(ang) * len, y: y + sin(ang) * len))
            context.stroke(p, with: .color((isDark ? lightSpeck : darkSpeck).opacity(0.05 + rng.unit() * 0.05)),
                           lineWidth: 0.5)
        }
    }
}

/// Deterministic SplitMix64 PRNG (no Foundation `UUID` dependency) for grain.
private struct SystemlessRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9e3779b97f4a7c15 : seed }
    mutating func unit() -> Double {
        state = state &+ 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        return Double(z >> 11) * (1.0 / 9007199254740992.0)
    }
}
