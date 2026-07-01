//
//  StickerOutlineCache.swift
//  drape
//
//  Caches the result of StickerOutline.apply (CoreImage dilate + supersample +
//  recomposite is CPU-heavy), keyed by asset id and a *bucketed* display size
//  so many near-identical sizes seen during scrolling/animation collapse onto
//  the same cache entry. Mirrors ImageCutoutService's actor-cache shape.
//

import CoreImage
import UIKit

actor StickerOutlineCache {
    static let shared = StickerOutlineCache()

    private struct Key: Hashable {
        let assetID: String
        let bucketedWidth: Int
        let bucketedHeight: Int
        let thicknessPoints: CGFloat
    }

    private let context = CIContext()
    private var cache: [Key: UIImage] = [:]

    /// Bucket width, in points — finer than any visible thickness difference,
    /// coarse enough to avoid cache explosion from continuous resizing.
    private static let bucket: CGFloat = 8

    /// The outlined variant of `source` for display at `displaySize`, or `nil`
    /// if `source` has no decodable `CGImage`.
    func outlinedImage(
        forAssetID assetID: String,
        source: UIImage,
        displaySize: CGSize,
        thicknessPoints: CGFloat
    ) -> UIImage? {
        guard !assetID.isEmpty, let cgImage = source.cgImage else { return nil }
        let key = Key(
            assetID: assetID,
            bucketedWidth: Int((displaySize.width / Self.bucket).rounded()),
            bucketedHeight: Int((displaySize.height / Self.bucket).rounded()),
            thicknessPoints: thicknessPoints
        )
        if let cached = cache[key] { return cached }

        let subject = CIImage(cgImage: cgImage)
        let outlined = StickerOutline.apply(
            to: subject,
            sourcePixelSize: CGSize(width: cgImage.width, height: cgImage.height),
            displaySize: displaySize,
            thicknessPoints: thicknessPoints
        )
        guard let output = context.createCGImage(outlined, from: outlined.extent) else {
            return nil
        }
        let result = UIImage(cgImage: output)
        cache[key] = result
        return result
    }
}
