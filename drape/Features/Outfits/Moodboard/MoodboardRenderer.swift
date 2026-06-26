//
//  MoodboardRenderer.swift
//  drape
//
//  Renders an outfit's collage to a shareable UIImage off the read-only detail
//  surfaces. Loads full-resolution cut-outs (shared cache), lays them out with
//  MoodboardLayout, and rasterizes MoodboardCanvas via ImageRenderer.
//

import SwiftUI
import UIKit

enum MoodboardRenderer {
    /// Standard portrait export frame.
    nonisolated static let exportSize = CGSize(width: 1080, height: 1350)

    @MainActor
    static func renderImage(garments: [Garment],
                            container: AppContainer,
                            colorScheme: ColorScheme,
                            size: CGSize = exportSize) async -> UIImage? {
        var cutouts: [UUID: UIImage] = [:]
        var fallbacks: [UUID: UIImage] = [:]
        for garment in garments {
            if let image = await CutoutImageCache.shared.cutoutImage(
                forAssetID: garment.imageAssetID, via: container.cutout) {
                cutouts[garment.id] = image
            } else if let data = try? await container.imageStore.loadThumbnailData(id: garment.thumbnailAssetID),
                      let image = UIImage(data: data) {
                fallbacks[garment.id] = image
            }
        }

        let renderer = ImageRenderer(content:
            MoodboardCanvas(
                placements: MoodboardLayout.place(garments),
                cutouts: cutouts,
                fallbacks: fallbacks,
                size: size
            )
            .frame(width: size.width, height: size.height)
            // AppBackground reads `\.colorScheme` from the environment; inject the
            // caller's scheme so the export matches the on-screen appearance
            // (ImageRenderer otherwise resolves to light).
            .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = 2
        return renderer.uiImage
    }
}
