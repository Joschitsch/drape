//
//  NormalizedImageView.swift
//  drape
//
//  Loads a garment image (or thumbnail) from the ImageStore by asset id, with a
//  category-appropriate placeholder when no image exists yet.
//

import SwiftUI
import UIKit

/// Displays a garment image resolved from the `ImageStore` in the environment.
/// Shows a tinted placeholder while loading or when the asset is missing — the
/// common case in Step 1 before real capture exists.
struct NormalizedImageView: View {
    let assetID: String
    let category: GarmentCategory
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
                placeholder
            }
        }
        .task(id: assetID) { await load() }
    }

    private var placeholder: some View {
        GarmentCanvasView(category: category, color: .brown)
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
