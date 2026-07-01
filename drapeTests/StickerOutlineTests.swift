//
//  StickerOutlineTests.swift
//  drapeTests
//
//  Validates StickerOutline's core radius formula against a synthetic
//  non-rectangular alpha shape — no Vision dependency, so it runs in the
//  Simulator (VNGenerateForegroundInstanceMaskRequest does not).
//

import Testing
import CoreImage
import UIKit
@testable import drape

@Suite("StickerOutline")
struct StickerOutlineTests {
    /// A synthetic circular alpha mask of `diameter` source pixels, centered
    /// in a square canvas with generous padding so the dilated halo never
    /// clips against the canvas edge.
    private func circleSubject(diameter: CGFloat) -> (image: CIImage, pixelSize: CGSize) {
        let side = diameter * 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))
        let uiImage = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
            UIColor.black.setFill()
            let rect = CGRect(x: side / 4, y: side / 4, width: diameter, height: diameter)
            ctx.cgContext.fillEllipse(in: rect)
        }
        return (CIImage(cgImage: uiImage.cgImage!), CGSize(width: side, height: side))
    }

    /// Measures the white halo's thickness (in source pixels) along a
    /// horizontal scanline through the shape's vertical center, by counting
    /// opaque, near-white pixels outside the original black circle's radius.
    private func measuredHaloWidth(outlined: CIImage, pixelSize: CGSize) -> CGFloat {
        let context = CIContext()
        let extent = CGRect(origin: .zero, size: CGSize(width: pixelSize.width, height: pixelSize.height))
        guard let cgImage = context.createCGImage(outlined, from: outlined.extent.union(extent)) else {
            return 0
        }
        let width = cgImage.width
        let height = cgImage.height
        guard let data = cgImage.dataProvider?.data,
              let bytes = CFDataGetBytePtr(data) else { return 0 }
        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow
        let row = height / 2

        var whiteCount = 0
        for x in 0..<width {
            let offset = row * bytesPerRow + x * bytesPerPixel
            guard offset + 3 < CFDataGetLength(data) else { continue }
            let r = bytes[offset], g = bytes[offset + 1], b = bytes[offset + 2], a = bytes[offset + 3]
            if a > 200, r > 240, g > 240, b > 240 {
                whiteCount += 1
            }
        }
        return CGFloat(whiteCount)
    }

    @Test("Larger display size requires a smaller source-pixel dilation radius")
    func radiusScalesInverselyWithDisplayScale() {
        let (subject, pixelSize) = circleSubject(diameter: 200)
        let thickness: CGFloat = 10

        // Displayed near 1:1 (scaleToDisplay ~= 1) needs ~10px of dilation.
        let smallDisplay = CGSize(width: pixelSize.width, height: pixelSize.height)
        // Displayed 4x larger (scaleToDisplay ~= 4) needs only ~2.5px of dilation.
        let largeDisplay = CGSize(width: pixelSize.width * 4, height: pixelSize.height * 4)

        let outlinedSmall = StickerOutline.apply(
            to: subject, sourcePixelSize: pixelSize, displaySize: smallDisplay, thicknessPoints: thickness)
        let outlinedLarge = StickerOutline.apply(
            to: subject, sourcePixelSize: pixelSize, displaySize: largeDisplay, thicknessPoints: thickness)

        let widthAtSmallDisplay = measuredHaloWidth(outlined: outlinedSmall, pixelSize: pixelSize) / 2
        let widthAtLargeDisplay = measuredHaloWidth(outlined: outlinedLarge, pixelSize: pixelSize) / 2

        // The halo drawn for the 4x-larger display should be meaningfully
        // thinner in *source pixels* than the one drawn for the ~1x display,
        // since a smaller source-pixel dilation reads as the same on-screen
        // thickness once magnified 4x.
        #expect(widthAtSmallDisplay > widthAtLargeDisplay)
        #expect(widthAtLargeDisplay > 0, "halo should not fully disappear")
    }

    @Test("Output extent grows beyond the input subject's extent")
    func haloExtendsBeyondSubject() {
        let (subject, pixelSize) = circleSubject(diameter: 200)
        let outlined = StickerOutline.apply(
            to: subject, sourcePixelSize: pixelSize,
            displaySize: pixelSize, thicknessPoints: 10)

        #expect(outlined.extent.width >= subject.extent.width)
        #expect(outlined.extent.height >= subject.extent.height)
    }

    @Test("Zero thickness returns the subject unchanged")
    func zeroThicknessIsNoOp() {
        let (subject, pixelSize) = circleSubject(diameter: 200)
        let outlined = StickerOutline.apply(
            to: subject, sourcePixelSize: pixelSize,
            displaySize: pixelSize, thicknessPoints: 0)

        #expect(outlined.extent == subject.extent)
    }
}
