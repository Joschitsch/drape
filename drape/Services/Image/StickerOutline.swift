//
//  StickerOutline.swift
//  drape
//
//  Adds a white "sticker" halo that hugs a garment cut-out's alpha silhouette,
//  sized so it reads as a constant on-screen thickness regardless of how much
//  the source image ends up scaled to fit its display box (a Wardrobe grid
//  tile vs. a small Moodboard footwear slot vs. a detail hero all use the same
//  source asset at wildly different display scales). This is a presentation-
//  layer effect, applied at render time — never baked into stored images, the
//  same way corner radius and shadow are ordinary view-level modifiers here.
//

import CoreImage

enum StickerOutline {
    /// Internal working-resolution multiplier before the final downsample, so
    /// the dilated edge is anti-aliased rather than blocky.
    nonisolated private static let supersample: CGFloat = 2

    /// Adds a white halo to `subject` sized so it reads as `thicknessPoints`
    /// wide on screen once `subject` (whose own pixel size is `sourcePixelSize`)
    /// is displayed at `displaySize` points.
    ///
    /// `subject` will be scaled by
    ///   scaleToDisplay = min(displaySize.width / sourcePixelSize.width,
    ///                        displaySize.height / sourcePixelSize.height)
    /// to fit its box (mirrors `.scaledToFit`). So 1 pixel of dilation in the
    /// source's own pixel space ends up covering `scaleToDisplay` points on
    /// screen. To get `thicknessPoints` of on-screen halo, dilate by:
    ///   radiusPx = thicknessPoints / scaleToDisplay
    /// clamped to a minimum of ~1 source pixel so the halo never disappears to
    /// float rounding when the image is shown far larger than its source
    /// pixels (e.g. a zoomed hero).
    nonisolated static func apply(
        to subject: CIImage,
        sourcePixelSize: CGSize,
        displaySize: CGSize,
        thicknessPoints: CGFloat,
        color: CIColor = .white
    ) -> CIImage {
        guard thicknessPoints > 0,
              sourcePixelSize.width > 0, sourcePixelSize.height > 0,
              displaySize.width > 0, displaySize.height > 0 else {
            return subject
        }
        let scaleToDisplay = min(displaySize.width / sourcePixelSize.width,
                                  displaySize.height / sourcePixelSize.height)
        guard scaleToDisplay > 0 else { return subject }
        let radiusPx = max(thicknessPoints / scaleToDisplay, 1)
        return dilatedAndRecomposited(subject: subject, radiusPx: radiusPx, color: color)
    }

    /// Dilate the alpha channel outward by `radiusPx` (following the existing
    /// silhouette edge), flood the dilated shape solid white, then composite
    /// the original subject back on top so the white only shows as a hard ring
    /// hugging the silhouette. Runs at `supersample`× resolution and
    /// Lanczos-downsamples the result, so the halo's edge is smooth rather
    /// than inheriting the source mask's native blockiness at full strength.
    nonisolated private static func dilatedAndRecomposited(
        subject: CIImage, radiusPx: CGFloat, color: CIColor
    ) -> CIImage {
        let upscaled = subject.transformed(by: CGAffineTransform(scaleX: supersample, y: supersample))
        let dilated = upscaled.applyingFilter(
            "CIMorphologyMaximum",
            parameters: [kCIInputRadiusKey: radiusPx * supersample])
        let whiteFill = CIImage(color: color).cropped(to: dilated.extent)
        let whiteHalo = whiteFill.applyingFilter(
            "CISourceInCompositing",
            parameters: [kCIInputBackgroundImageKey: dilated])
        let composedUp = upscaled.composited(over: whiteHalo)
        let downscaled = composedUp.applyingFilter(
            "CILanczosScaleTransform",
            parameters: [kCIInputScaleKey: 1.0 / supersample])

        // The scale transform moves extent.origin proportionally; translate
        // back so the result lines up with the original subject's origin.
        let dx = subject.extent.origin.x - downscaled.extent.origin.x
        let dy = subject.extent.origin.y - downscaled.extent.origin.y
        return downscaled.transformed(by: CGAffineTransform(translationX: dx, y: dy))
    }
}
