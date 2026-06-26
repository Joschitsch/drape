//
//  MoodboardThumbnail.swift
//  drape
//
//  A non-interactive (or lightly tappable) collage of an outfit's garments — the
//  shared visual language for the Outfits list, recommendations, and the
//  read-only outfit detail board. The collage is composed at a canonical aspect
//  ratio and centred within whatever frame it's given (paper fills the rest), so
//  a wide card and a tall detail show the *identical* composition at different
//  sizes. Cut-outs load lazily via the shared CutoutImageCache.
//

import SwiftUI
import UIKit

struct MoodboardThumbnail: View {
    let garments: [Garment]
    /// Load full-resolution cut-outs (detail board) vs. lightweight thumbnails
    /// (lists). Lists stay cheap; the full-screen detail stays crisp.
    var useFullResolution: Bool = false
    /// When set, tapping a piece reports its garment (read-only detail board).
    var onTapPiece: ((Garment) -> Void)? = nil

    @Environment(AppContainer.self) private var container
    @State private var cutouts: [UUID: UIImage] = [:]
    @State private var fallbacks: [UUID: UIImage] = [:]

    private var placements: [PlacedGarment] { MoodboardLayout.place(garments) }

    var body: some View {
        GeometryReader { geo in
            let inner = fitted(in: geo.size)
            ZStack {
                AppBackground()
                MoodboardCanvas(
                    placements: placements,
                    cutouts: cutouts,
                    fallbacks: fallbacks,
                    onTapPiece: onTapPiece.map { handler in
                        { id in if let g = garments.first(where: { $0.id == id }) { handler(g) } }
                    },
                    showsBackground: false,
                    size: inner
                )
                .frame(width: inner.width, height: inner.height)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
        .task(id: garments.map(\.id)) { await load() }
    }

    /// Largest box of the canonical aspect ratio that fits inside `size`.
    private func fitted(in size: CGSize) -> CGSize {
        let ratio = MoodboardLayout.aspectRatio // w / h
        if size.width / size.height > ratio {
            return CGSize(width: size.height * ratio, height: size.height)
        } else {
            return CGSize(width: size.width, height: size.width / ratio)
        }
    }

    private func load() async {
        for garment in garments {
            let id = garment.id
            if cutouts[id] != nil || fallbacks[id] != nil { continue }
            let assetID = useFullResolution ? garment.imageAssetID : garment.thumbnailAssetID
            if let image = await CutoutImageCache.shared.cutoutImage(forAssetID: assetID, via: container.cutout) {
                cutouts[id] = image
            } else if let data = try? await container.imageStore.loadThumbnailData(id: garment.thumbnailAssetID),
                      let image = UIImage(data: data) {
                fallbacks[id] = image
            }
        }
    }
}
