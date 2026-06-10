//
//  GarmentImageFactory.swift
//  drape
//
//  Renders a simple "product" image for demo garments — the category icon on a
//  soft tint of the garment's color — so seeded data shows a picture without
//  any real photography. Real garments use their captured photo instead.
//

import SwiftUI
import UIKit

@MainActor
enum GarmentImageFactory {
    /// A baked product image: the category symbol centered on a soft color wash.
    /// Returns a `ProcessedImage` ready to hand to the `ImageStore`.
    static func makeImage(category: GarmentCategory, color: ColorTag) -> ProcessedImage? {
        // Square, matching the 1:1 canvas real captured garments are normalized to.
        let side: CGFloat = 1024
        let renderer = ImageRenderer(content:
            GarmentImageCard(category: category, color: color)
                .frame(width: side, height: side)
        )
        renderer.scale = 1
        guard let full = renderer.uiImage,
              let fullData = full.pngData() else { return nil }

        let thumb = downscale(full, to: CGSize(width: 320, height: 320))
        let thumbData = thumb.pngData() ?? fullData
        return ProcessedImage(imageData: fullData, thumbnailData: thumbData, pixelSize: full.size)
    }

    private static func downscale(_ image: UIImage, to target: CGSize) -> UIImage {
        let r = UIGraphicsImageRenderer(size: target)
        return r.image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }
}

/// The rendered card. Uses fixed (non-adaptive) colors because the result is
/// baked into a bitmap — like a photo, it should not invert in dark mode.
private struct GarmentImageCard: View {
    let category: GarmentCategory
    let color: ColorTag

    private var washTop: Color { color.color.mix(with: .white, by: 0.78) }
    private var washBottom: Color { color.color.mix(with: .white, by: 0.90) }
    private var ink: Color { Color(hex: "2A2722").opacity(0.55) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [washTop, washBottom],
                           startPoint: .top, endPoint: .bottom)
            Image(category.iconName)
                .font(.system(size: 440))
                .foregroundStyle(ink)
        }
    }
}
