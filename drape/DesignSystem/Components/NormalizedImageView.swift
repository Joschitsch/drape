//
//  NormalizedImageView.swift
//  drape
//
//  Loads a garment image (or thumbnail) from the ImageStore by asset id. Every
//  garment has an image (the capture flow requires one; demo data is seeded with
//  generated images), so the only no-image state is the brief moment while the
//  bytes load — shown as a neutral surface.
//

import SwiftUI
import UIKit

/// Displays a garment image resolved from the `ImageStore` in the environment.
struct NormalizedImageView: View {
    let assetID: String
    var useThumbnail: Bool = true
    /// When set, draws a white sticker outline sized for this exact on-screen
    /// box — pass the same size given to the `.frame(...)` modifier applied to
    /// this view. `nil` (default) draws no outline.
    var displaySize: CGSize? = nil
    var outlineThickness: CGFloat = Theme.stickerOutlineThickness

    @Environment(AppContainer.self) private var container
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            // Transparent while the bytes load, so a fast scroll never flashes a
            // white/opaque placeholder — the image fades in from clear instead.
            Color.clear
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: image != nil)
        .task(id: assetID) { await load() }
    }

    private func load() async {
        guard !assetID.isEmpty else { image = nil; return }
        let store = container.imageStore
        do {
            let data = useThumbnail
                ? try await store.loadThumbnailData(id: assetID)
                : try await store.loadImageData(id: assetID)
            guard let decoded = UIImage(data: data) else { image = nil; return }
            if let displaySize {
                image = await StickerOutlineCache.shared.outlinedImage(
                    forAssetID: assetID, source: decoded,
                    displaySize: displaySize, thicknessPoints: outlineThickness
                ) ?? decoded
            } else {
                image = decoded
            }
        } catch {
            image = nil
        }
    }
}
