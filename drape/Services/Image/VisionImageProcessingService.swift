//
//  VisionImageProcessingService.swift
//  drape
//
//  On-device image normalization: lift the garment off its background with
//  Vision and composite it onto a consistent neutral square canvas.
//

import Foundation
import Vision
import CoreImage
import UIKit

/// Produces a visually consistent wardrobe image entirely on-device (no cost,
/// no network — see the project cost constraint).
///
/// Pipeline: decode → fix orientation → Vision foreground-instance mask →
/// composite the cut-out onto a transparent square canvas with padding → encode
/// full image + thumbnail as PNG. The garment floats on the app's Warm Linen
/// background (see AppBackground) rather than a baked-in canvas color. If no
/// subject is found (or Vision is unavailable) it falls back to fitting the
/// original image onto the same canvas, so capture never hard-fails.
struct VisionImageProcessingService: ImageProcessingService {
    /// Side length of the full normalized image, in pixels.
    var fullSide: CGFloat = 1024
    /// Side length of the thumbnail, in pixels.
    var thumbnailSide: CGFloat = 320
    /// Fraction of the canvas the subject is inset by on each side.
    var paddingFraction: CGFloat = 0.08
    /// Fully transparent canvas so the garment cut-out floats on whatever surface
    /// shows it (the app's Warm Linen background).
    var canvasColor = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
    /// Mild blur applied to the subject's alpha before compositing, in pixels at
    /// `fullSide` resolution (scaled proportionally for the thumbnail) — softens
    /// Vision's native mask blockiness so the cut-out's own edge reads cleanly.
    var alphaSmoothingRadius: CGFloat = 1.5

    private let context = CIContext()

    func normalize(imageData: Data) async throws -> ProcessedImage {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.orientedUp().cgImage else {
            throw ImageProcessingError.invalidImageData
        }

        // Subject cut-out (transparent background) or fallback to the full frame.
        let subject = (try? VisionForegroundCutout.maskedImage(from: cgImage))
            ?? CIImage(cgImage: cgImage)

        let full = try render(subject: subject, side: fullSide)
        let thumb = try render(subject: subject, side: thumbnailSide)

        return ProcessedImage(
            imageData: full,
            thumbnailData: thumb,
            pixelSize: CGSize(width: fullSide, height: fullSide)
        )
    }

    // MARK: - Compositing

    /// Centers and scales the subject onto a transparent square canvas, then
    /// encodes PNG data at the requested side length.
    private func render(subject: CIImage, side: CGFloat) throws -> Data {
        let canvasRect = CGRect(x: 0, y: 0, width: side, height: side)
        let canvas = CIImage(color: canvasColor).cropped(to: canvasRect)

        // Scale the subject to fit inside the padded content area.
        let inset = side * paddingFraction
        let content = side - inset * 2
        let extent = subject.extent
        let scale = min(content / max(extent.width, 1), content / max(extent.height, 1))

        let scaled = subject
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let tx = (side - scaledExtent.width) / 2 - scaledExtent.origin.x
        let ty = (side - scaledExtent.height) / 2 - scaledExtent.origin.y
        let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))
        let smoothed = smoothedEdge(of: centered, radiusPx: alphaSmoothingRadius * (side / fullSide))

        let composite = smoothed.composited(over: canvas).cropped(to: canvasRect)

        guard let cgImage = context.createCGImage(composite, from: canvasRect) else {
            throw ImageProcessingError.renderingFailed
        }
        guard let data = UIImage(cgImage: cgImage).pngData() else {
            throw ImageProcessingError.renderingFailed
        }
        return data
    }

    /// Softens Vision's native mask blockiness with a mild Gaussian blur, then
    /// re-clamps to the blurred extent so the blur doesn't shrink the subject's
    /// apparent bounds.
    private func smoothedEdge(of subject: CIImage, radiusPx: CGFloat) -> CIImage {
        guard radiusPx > 0 else { return subject }
        return subject
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radiusPx])
            .cropped(to: subject.extent.insetBy(dx: -radiusPx, dy: -radiusPx))
    }
}

private extension UIImage {
    /// Redraws the image with its orientation baked in so downstream CoreGraphics
    /// work isn't rotated. Cheap no-op when already `.up`.
    func orientedUp() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
