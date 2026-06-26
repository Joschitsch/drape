//
//  AppBackground.swift
//  drape
//
//  The single "Warm Linen" surface every garment- and outfit-showing screen sits
//  on. Fully procedural (no asset; renders inside `ImageRenderer` for Moodboard
//  export) and tactile: a warm flat base, a two-pass grain blended multiply
//  (light) / screen (dark), and soft radial light/shadow overlays.
//
//  Colors are chosen from the explicit color scheme — NOT via dynamic
//  (`Theme.adaptive`) colors — because `Canvas`/`GraphicsContext` resolves
//  dynamic colors against the light trait, which made the texture invisible in
//  dark mode in-app while still rendering in exports. Callers that rasterize this
//  via `ImageRenderer` must inject `\.colorScheme` so the export matches on-screen.
//

import SwiftUI

struct AppBackground: View {
    var seed: UInt64 = 0x5eed_1234

    @Environment(\.colorScheme) private var scheme

    private var isDark: Bool { scheme == .dark }

    private var base: Color { isDark ? Color(hex: "1C1914") : Color(hex: "DDD3C4") }
    private var darkSpeck: Color { isDark ? Color(hex: "0E0B07") : Color(hex: "5E4B33") }
    private var lightSpeck: Color { isDark ? Color(hex: "C9BCA6") : Color(hex: "FFFFFF") }

    var body: some View {
        GeometryReader { geo in
            let maxDim = max(geo.size.width, geo.size.height)
            ZStack {
                base

                // Fine paper grain. Multiply darkens the linen in light mode;
                // screen lifts it in dark mode — the SwiftUI equivalent of the
                // spec's fractalNoise + mix-blend-mode.
                Canvas { context, size in
                    drawGrain(&context, size)
                    drawFibers(&context, size)
                }
                .blendMode(isDark ? .screen : .multiply)
                .opacity(isDark ? 0.20 : 0.5)

                overlays(maxDim: maxDim)
            }
        }
    }

    /// Soft directional light + warm shadow pooled at opposite corners.
    @ViewBuilder
    private func overlays(maxDim: CGFloat) -> some View {
        if isDark {
            RadialGradient(colors: [Color(hex: "3C2D16").opacity(0.20), .clear],
                           center: .init(x: 0.5, y: 0.0),
                           startRadius: 0, endRadius: 0.6 * maxDim)
        } else {
            RadialGradient(colors: [Color(hex: "FFF5E1").opacity(0.55), .clear],
                           center: .init(x: 0.4, y: 0.2),
                           startRadius: 0, endRadius: 0.5 * maxDim)
            RadialGradient(colors: [Color(hex: "645037").opacity(0.30), .clear],
                           center: .init(x: 0.7, y: 0.9),
                           startRadius: 0, endRadius: 0.5 * maxDim)
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
