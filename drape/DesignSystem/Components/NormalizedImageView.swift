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

    @Environment(AppContainer.self) private var container
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                // Neutral block while the image loads.
                Theme.surface
            }
        }
        .task(id: assetID) { await load() }
    }

    private func load() async {
        guard !assetID.isEmpty else { image = nil; return }
        let store = container.imageStore
        do {
            let data = useThumbnail
                ? try await store.loadThumbnailData(id: assetID)
                : try await store.loadImageData(id: assetID)
            image = UIImage(data: data)
        } catch {
            image = nil
        }
    }
}
