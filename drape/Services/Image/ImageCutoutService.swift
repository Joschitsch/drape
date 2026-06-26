//
//  ImageCutoutService.swift
//  drape
//
//  Produces transparent garment cut-outs for the Moodboard collage. Stored
//  garment PNGs are opaque (the capture pipeline flattens the subject onto a
//  neutral canvas), so the floating-collage look re-extracts a transparent
//  subject from the normalized full image with Vision, on-device, and caches it.
//

import Foundation
import CoreImage
import UIKit

/// Resolves a garment's stored full image into a transparent-background PNG,
/// cached in memory by asset id. An actor so the cache and the (CPU-heavy)
/// Vision pass stay off the main thread; callers turn the returned `Data` into a
/// `UIImage` where they need it (mirrors `NormalizedImageView`).
actor ImageCutoutService {
    private let store: any ImageStore
    private var cache: [String: Data] = [:]

    init(store: any ImageStore) {
        self.store = store
    }

    /// Transparent-cutout PNG bytes for the asset, or `nil` if the asset is
    /// missing or Vision finds no subject (caller falls back to the opaque image).
    func cutoutPNGData(forAssetID id: String) async -> Data? {
        guard !id.isEmpty else { return nil }
        if let cached = cache[id] { return cached }
        guard let full = try? await store.loadImageData(id: id),
              let data = Self.makeCutoutPNG(from: full) else { return nil }
        cache[id] = data
        return data
    }

    // MARK: - Vision pass (pure, off-actor-state)

    /// Lifts the subject off its background and encodes it as a transparent PNG.
    /// Returns `nil` when no subject is found.
    nonisolated private static func makeCutoutPNG(from imageData: Data) -> Data? {
        guard let cgImage = UIImage(data: imageData)?.cgImage,
              let masked = try? VisionForegroundCutout.maskedImage(from: cgImage),
              let output = CIContext().createCGImage(masked, from: masked.extent) else {
            return nil
        }
        return UIImage(cgImage: output).pngData()
    }
}
