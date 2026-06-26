//
//  GarmentCutoutMigration.swift
//  drape
//
//  One-time, self-contained migration. Early garment PNGs were flattened onto an
//  opaque neutral-gray canvas by the capture pipeline; the app now floats garment
//  cut-outs on the Warm Linen background (see AppBackground), so those stored
//  files are re-processed once into transparent cut-outs and overwritten in place.
//
//  Runs exactly once, gated by a single UserDefaults flag. After it completes it
//  is dormant forever and touches no shared code path — the only shared symbol it
//  reuses is `VisionForegroundCutout`. This whole file can be deleted in a future
//  cleanup without affecting anything else.
//

import Foundation
import CoreImage
import UIKit

enum GarmentCutoutMigration {
    /// Set once the migration has run; checked on every launch so it never repeats.
    private static let completedKey = "cutoutMigrationV1Complete"

    // Match the capture pipeline (VisionImageProcessingService) so re-processed
    // images keep the same framing as freshly captured ones.
    private static let fullSide: CGFloat = 1024
    private static let thumbnailSide: CGFloat = 320
    private static let paddingFraction: CGFloat = 0.08

    /// Re-processes every garment's stored PNG into a transparent cut-out, exactly
    /// once. Garments whose subject Vision can't find are left untouched. Safe to
    /// call on every launch — it returns immediately once the flag is set.
    @MainActor
    static func run(garments: [Garment], imageStore: any ImageStore) async {
        guard !UserDefaults.standard.bool(forKey: completedKey) else { return }

        // Read the (Sendable) asset ids on the main actor before doing any work
        // off it — `Garment` is a SwiftData model and isn't safe to touch from
        // the background.
        let assets = garments
            .map { (full: $0.imageAssetID, thumb: $0.thumbnailAssetID) }
            .filter { !$0.full.isEmpty }

        let directory = imagesDirectory()
        for asset in assets {
            await migrate(full: asset.full, thumb: asset.thumb,
                          directory: directory, imageStore: imageStore)
        }

        UserDefaults.standard.set(true, forKey: completedKey)
    }

    // MARK: - Per-garment (runs off the main actor)

    private static func migrate(full: String, thumb: String,
                                directory: URL, imageStore: any ImageStore) async {
        guard let data = try? await imageStore.loadImageData(id: full),
              let cgImage = UIImage(data: data)?.cgImage else { return }

        // Fallback: no subject found → leave the original PNG untouched.
        guard let subject = try? VisionForegroundCutout.maskedImage(from: cgImage) else { return }

        let context = CIContext()
        guard let fullPNG = render(subject: subject, side: fullSide, context: context) else { return }
        try? fullPNG.write(to: directory.appendingPathComponent(full, isDirectory: false),
                           options: .atomic)

        if !thumb.isEmpty,
           let thumbPNG = render(subject: subject, side: thumbnailSide, context: context) {
            try? thumbPNG.write(to: directory.appendingPathComponent(thumb, isDirectory: false),
                                options: .atomic)
        }
    }

    /// Centers and scales the transparent subject onto a clear square canvas, then
    /// PNG-encodes it. Mirrors `VisionImageProcessingService.render` (deliberately
    /// duplicated so this migration stays self-contained and deletable).
    private static func render(subject: CIImage, side: CGFloat, context: CIContext) -> Data? {
        let canvasRect = CGRect(x: 0, y: 0, width: side, height: side)
        let canvas = CIImage(color: CIColor(red: 0, green: 0, blue: 0, alpha: 0)).cropped(to: canvasRect)

        let inset = side * paddingFraction
        let content = side - inset * 2
        let extent = subject.extent
        let scale = min(content / max(extent.width, 1), content / max(extent.height, 1))

        let scaled = subject.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let scaledExtent = scaled.extent
        let tx = (side - scaledExtent.width) / 2 - scaledExtent.origin.x
        let ty = (side - scaledExtent.height) / 2 - scaledExtent.origin.y
        let centered = scaled.transformed(by: CGAffineTransform(translationX: tx, y: ty))

        let composite = centered.composited(over: canvas).cropped(to: canvasRect)

        guard let cgImage = context.createCGImage(composite, from: canvasRect) else { return nil }
        return UIImage(cgImage: cgImage).pngData()
    }

    /// The on-disk image directory. Mirrors `FileImageStore` (which exposes no
    /// write-by-id) so files can be overwritten in place without changing asset
    /// ids or the `ImageStore` protocol.
    private static func imagesDirectory() -> URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        return base.appendingPathComponent("Images", isDirectory: true)
    }
}
