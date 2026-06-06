//
//  GarmentCanvasView.swift
//  drape
//
//  The "museum canvas" — a tonal placeholder that gives every garment a
//  considered, editorial look when no real photograph is available (preview
//  data, loading skeleton, missing image). Background color is derived from
//  the garment's primary color.
//

import SwiftUI

struct GarmentCanvasView: View {
    let category: GarmentCategory
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // ── Tonal gradient wash ──────────────────────────────
                LinearGradient(
                    colors: [color.opacity(0.26), color.opacity(0.13)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // ── Vertical stripe texture ──────────────────────────
                Canvas { ctx, size in
                    var x: CGFloat = 0
                    while x < size.width {
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(path, with: .color(color.opacity(0.06)), lineWidth: 1)
                        x += 7
                    }
                }

                // ── Category glyph ───────────────────────────────────
                let side = min(geo.size.width, geo.size.height) * 0.42
                Image(systemName: category.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: side, height: side)
                    .foregroundStyle(color.opacity(0.45))
                    .fontWeight(.ultraLight)
            }
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(GarmentCategory.allCases) { cat in
            GarmentCanvasView(category: cat, color: .brown)
                .frame(width: 80, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    .padding()
}
