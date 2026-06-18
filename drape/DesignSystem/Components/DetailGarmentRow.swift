//
//  DetailGarmentRow.swift
//  drape
//
//  The large, tappable garment row used inside outfit / suggestion detail
//  stacks: portrait thumbnail, category kicker, serif name, brand, color dot
//  and a disclosure chevron. Shared by OutfitDetailView and the Style tab's
//  suggestion detail so both read identically.
//

import SwiftUI

struct DetailGarmentRow: View {
    let garment: Garment

    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(width: 66, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: Theme.shadow, radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(garment.category.displayName, size: 8.5)
                SerifText(garment.displayName, size: 16).lineLimit(1)
                if let brand = garment.brand, !brand.isEmpty {
                    Text(brand).font(Theme.body(12.5)).foregroundStyle(Theme.inkSoft)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Circle()
                    .fill(garment.displayColor)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}
