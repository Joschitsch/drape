//
//  CutoutImageCache.swift
//  drape
//
//  App-wide decode-once cache for transparent garment cut-outs, keyed by asset
//  id. The editor board and the list/recommendation thumbnails all share it, so
//  a garment's cut-out is computed by Vision (via ImageCutoutService) and decoded
//  to a UIImage at most once, then reused — cheap enough to render in scrolling
//  lists.
//

import UIKit

@MainActor
final class CutoutImageCache {
    static let shared = CutoutImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 240
    }

    /// The transparent cut-out for an asset, or `nil` if the asset is missing or
    /// Vision finds no subject. Full vs. thumbnail assets have distinct ids, so
    /// the id alone is a correct cache key.
    func cutoutImage(forAssetID assetID: String, via service: ImageCutoutService) async -> UIImage? {
        guard !assetID.isEmpty else { return nil }
        let key = assetID as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let data = await service.cutoutPNGData(forAssetID: assetID),
              let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }
}
