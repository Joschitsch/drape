//
//  GarmentTile.swift
//  drape
//
//  Square wardrobe-grid cell for a single garment.
//

import SwiftUI

/// A square tile showing a garment's normalised image with a color swatch and
/// category caption. Used by the wardrobe grid.
struct GarmentTile: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .overlay(alignment: .topTrailing) {
                    if garment.isFavorite {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(.pink)
                            .padding(8)
                    }
                }

            HStack(spacing: 6) {
                Circle()
                    .fill(garment.primaryColor.color)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                Text(garment.category.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
