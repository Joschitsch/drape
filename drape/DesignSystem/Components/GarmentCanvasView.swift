//
//  GarmentCanvasView.swift
//  drape
//
//  The "museum canvas" — a tonal placeholder that gives every garment a
//  considered, editorial look when no real photograph is available (preview
//  data, loading skeleton, missing image). The wash, glyph and color name are
//  all derived from the garment's primary color.
//

import SwiftUI

struct GarmentCanvasView: View {
    let category: GarmentCategory
    let colorTag: ColorTag
    /// Draw the category outline glyph in the center.
    var showGlyph: Bool = true
    /// Show the uppercase color name in the bottom-left (the `mono` treatment).
    var showColorName: Bool = false

    private var base: Color { colorTag.color }
    /// Wash tints: the design mixes the color toward the neutral canvas base
    /// (white in light, deep warm graphite in dark) — 26% / 13% color.
    private var washTop: Color { base.mix(with: Theme.canvasBase, by: 0.74) }
    private var washBottom: Color { base.mix(with: Theme.canvasBase, by: 0.87) }
    /// Glyph / label ink: color mixed toward an adaptive warm graphite.
    private var mark: Color { base.mix(with: Theme.canvasGraphite, by: 0.38) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Tonal gradient wash (≈155°) ──────────────────────
                LinearGradient(
                    colors: [washTop, washBottom],
                    startPoint: UnitPoint(x: 0.15, y: 0),
                    endPoint: UnitPoint(x: 0.85, y: 1)
                )

                // ── Vertical stripe texture (1pt every 7pt, 10%) ─────
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(path, with: .color(base.opacity(0.10)), lineWidth: 1)
                        x += 7
                    }
                }

                // ── Category glyph (hand-drawn outline) ──────────────
                if showGlyph {
                    let side = min(geo.size.width, geo.size.height) * 0.58
                    CategoryGlyph(category: category)
                        .stroke(mark.opacity(0.5),
                                style: StrokeStyle(lineWidth: max(1, side / 48 * 1.4),
                                                   lineCap: .round, lineJoin: .round))
                        .frame(width: side, height: side)
                }

                // ── Color name (mono, bottom-left) ───────────────────
                if showColorName {
                    VStack {
                        Spacer()
                        HStack {
                            Text(colorTag.displayName.uppercased())
                                .font(Theme.mono(9.5))
                                .tracking(0.3)
                                .foregroundStyle(mark.opacity(0.85))
                            Spacer()
                        }
                    }
                    .padding(.leading, 10)
                    .padding(.bottom, 9)
                }
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(Array(zip(GarmentCategory.allCases, ColorTag.allCases)), id: \.0) { cat, tag in
            GarmentCanvasView(category: cat, colorTag: tag, showColorName: true)
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
    .background(Theme.paper)
}
