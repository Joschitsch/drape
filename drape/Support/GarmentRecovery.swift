//
//  GarmentRecovery.swift
//  drape
//
//  Recovers garment photos that were orphaned when their records were lost (the
//  styles schema change forced a one-time store reset). The image files survive
//  in the image store; this resurrects the full-size ones as draft garments the
//  user can re-tag.
//

import Foundation
import SwiftData

enum GarmentRecovery {
    /// Minimum largest-side (px) to treat an orphan as a recoverable full photo
    /// rather than a thumbnail.
    private static let fullImageMinSide = 500

    /// Stored image files not referenced by any garment that look like full-size
    /// captures — i.e. recoverable photos.
    @MainActor
    static func orphanedPhotoIDs(context: ModelContext, imageStore: any ImageStore) async -> [String] {
        guard let garments = try? context.fetch(FetchDescriptor<Garment>()) else { return [] }
        let referenced = Set(garments.flatMap { [$0.imageAssetID, $0.thumbnailAssetID] }
            .filter { !$0.isEmpty })
        let all = (try? await imageStore.allImageIDs()) ?? []

        var result: [String] = []
        for id in all where !referenced.contains(id) {
            guard let data = try? await imageStore.loadImageData(id: id),
                  let (w, h) = PreviewData.pixelSize(of: data),
                  max(w, h) >= fullImageMinSide else { continue }
            result.append(id)
        }
        return result
    }

    /// Creates a draft garment for each recoverable photo. Returns the count.
    @MainActor
    @discardableResult
    static func recover(context: ModelContext, imageStore: any ImageStore) async -> Int {
        let ids = await orphanedPhotoIDs(context: context, imageStore: imageStore)
        for id in ids {
            // The full image doubles as the thumbnail — no original pairing exists.
            let garment = Garment(category: .top, primaryColor: .slate, name: "Recovered piece",
                                  imageAssetID: id, thumbnailAssetID: id)
            context.insert(garment)
        }
        if !ids.isEmpty { try? context.save() }
        return ids.count
    }
}
