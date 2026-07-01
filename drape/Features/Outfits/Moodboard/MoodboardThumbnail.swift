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
//  Two presentation modes:
//  • `showsBackground` (default true) draws the warm paper behind the collage.
//    The galleries pass `false` so the cut-outs float directly on the page.
//  • `fillsContent` (default false) fits the *garments' content box* to the frame
//    instead of the padded canonical canvas, so the outfit reads large in a
//    narrow cover-flow slot (the empty side-margins spill past the slot and clip).
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
    /// Draw the warm paper behind the collage. Off when the collage should float
    /// directly on the page's own background (the galleries).
    var showsBackground: Bool = true
    /// Fit the garments' content box (fill the frame) instead of the padded
    /// canonical canvas — larger collage at a narrow slot. Used by the galleries.
    var fillsContent: Bool = false

    @Environment(AppContainer.self) private var container
    @State private var cutouts: [UUID: UIImage] = [:]
    @State private var fallbacks: [UUID: UIImage] = [:]

    /// Fraction of the frame the content box fills in `fillsContent` mode; the
    /// remainder is breathing room so per-piece shadows aren't clipped.
    private let contentInset: CGFloat = 0.92

    private var placements: [PlacedGarment] { MoodboardLayout.place(garments) }

    /// Garments whose image hasn't loaded yet. Only surfaced on the large
    /// full-resolution board — small list thumbnails load from cache fast and a
    /// pulsing block would just flicker as you scroll.
    private var pending: Set<UUID> {
        guard useFullResolution else { return [] }
        return Set(garments.map(\.id))
            .subtracting(cutouts.keys)
            .subtracting(fallbacks.keys)
    }

    var body: some View {
        GeometryReader { geo in
            let layout = canvasLayout(in: geo.size)
            ZStack {
                if showsBackground {
                    AppBackground()
                }
                MoodboardCanvas(
                    placements: placements,
                    cutouts: cutouts,
                    fallbacks: fallbacks,
                    pending: pending,
                    onTapPiece: onTapPiece.map { handler in
                        { id in if let g = garments.first(where: { $0.id == id }) { handler(g) } }
                    },
                    showsBackground: false,
                    size: layout.canvasSize
                )
                .frame(width: layout.canvasSize.width, height: layout.canvasSize.height)
                .position(layout.center)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
            .task(id: LoadKey(garmentIDs: garments.map(\.id), canvasSize: layout.canvasSize)) {
                await load(canvasSize: layout.canvasSize)
            }
        }
    }

    private struct LoadKey: Equatable {
        let garmentIDs: [UUID]
        let canvasSize: CGSize
    }

    // MARK: - Layout

    private struct CanvasLayout {
        /// Size the `MoodboardCanvas` composes at.
        let canvasSize: CGSize
        /// Where the canvas centre lands inside the frame.
        let center: CGPoint
    }

    /// Where and how large to render the composition within `size`.
    private func canvasLayout(in size: CGSize) -> CanvasLayout {
        let ratio = MoodboardLayout.aspectRatio // w / h
        let frameCentre = CGPoint(x: size.width / 2, y: size.height / 2)

        // Canonical: largest aspect-ratio box, centred (thumbnail/detail parity).
        guard fillsContent, let bbox = contentBBox() else {
            let inner: CGSize = size.width / size.height > ratio
                ? CGSize(width: size.height * ratio, height: size.height)
                : CGSize(width: size.width, height: size.width / ratio)
            return CanvasLayout(canvasSize: inner, center: frameCentre)
        }

        // Content-fit: scale the canvas so the garments' content box fills the
        // frame (by its limiting dimension), then offset so that box is centred.
        let avail = CGSize(width: size.width * contentInset, height: size.height * contentInset)
        let contentRatio = (bbox.width / bbox.height) * ratio  // points w/h of the content box
        let display: CGSize = avail.width / avail.height > contentRatio
            ? CGSize(width: avail.height * contentRatio, height: avail.height)
            : CGSize(width: avail.width, height: avail.width / contentRatio)

        let canvasSize = CGSize(width: display.width / bbox.width,
                                height: display.height / bbox.height)
        let center = CGPoint(
            x: frameCentre.x + (0.5 - bbox.midX) * canvasSize.width,
            y: frameCentre.y + (0.5 - bbox.midY) * canvasSize.height
        )
        return CanvasLayout(canvasSize: canvasSize, center: center)
    }

    /// Bounding box of all placed pieces in normalized canvas space (0…1), or
    /// nil when there's nothing to place.
    private func contentBBox() -> CGRect? {
        let pieces = placements
        guard !pieces.isEmpty else { return nil }
        var xMin = CGFloat.greatestFiniteMagnitude, xMax = -CGFloat.greatestFiniteMagnitude
        var yMin = CGFloat.greatestFiniteMagnitude, yMax = -CGFloat.greatestFiniteMagnitude
        for p in pieces {
            xMin = min(xMin, p.center.x - p.widthFraction / 2)
            xMax = max(xMax, p.center.x + p.widthFraction / 2)
            yMin = min(yMin, p.center.y - p.heightFraction / 2)
            yMax = max(yMax, p.center.y + p.heightFraction / 2)
        }
        return CGRect(x: xMin, y: yMin, width: xMax - xMin, height: yMax - yMin)
    }

    // MARK: - Loading

    private func load(canvasSize: CGSize) async {
        for garment in garments {
            let id = garment.id
            if cutouts[id] != nil || fallbacks[id] != nil { continue }
            let assetID = useFullResolution ? garment.imageAssetID : garment.thumbnailAssetID
            let displaySize = placements.first { $0.id == id }.map {
                CGSize(width: $0.widthFraction * canvasSize.width, height: $0.heightFraction * canvasSize.height)
            } ?? canvasSize
            if let image = await CutoutImageCache.shared.cutoutImage(forAssetID: assetID, via: container.cutout) {
                cutouts[id] = await StickerOutlineCache.shared.outlinedImage(
                    forAssetID: assetID, source: image,
                    displaySize: displaySize, thicknessPoints: Theme.stickerOutlineThickness
                ) ?? image
            } else if let data = try? await container.imageStore.loadThumbnailData(id: garment.thumbnailAssetID),
                      let image = UIImage(data: data) {
                fallbacks[id] = image
            }
        }
    }
}
