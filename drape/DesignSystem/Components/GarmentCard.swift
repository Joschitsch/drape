//
//  GarmentCard.swift
//  drape
//
//  App Store Today-style hero card: photo fills the card edge-to-edge,
//  a Liquid Glass strip at the bottom carries the caption.
//

import SwiftUI

struct GarmentCard: View {
    let garment: Garment

    var body: some View {
        ZStack(alignment: .bottom) {
            // ── Full-bleed photo ─────────────────────────────────────
            NormalizedImageView(assetID: garment.imageAssetID, useThumbnail: false)

            // ── Overlays ─────────────────────────────────────────────
            GlassEffectContainer {
                ZStack(alignment: .bottom) {
                    // Favorite badge – top-trailing corner
                    if garment.isFavorite {
                        VStack {
                            HStack {
                                Spacer()
                                Image("drape.heart.fill")
                                    .foregroundStyle(Theme.ink)
                                    .padding(9)
                                    .glassEffect(.regular, in: Circle())
                                    .padding(12)
                            }
                            Spacer()
                        }
                    }

                    // Caption – full-width glass strip pinned to bottom
                    VStack(alignment: .leading, spacing: 3) {
                        MonoLabel(garment.category.displayName, size: 9)
                        SerifText(garment.displayName, size: 22)
                        if let brand = garment.brand, !brand.isEmpty {
                            Text(brand)
                                .font(Theme.body(13))
                                .foregroundStyle(Theme.inkSoft)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .glassEffect(.regular, in: Rectangle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.shadow, radius: 20, x: 0, y: 12)
    }
}

#Preview {
    let garment = PreviewData.sampleGarments().first!
    GarmentCard(garment: garment)
        .padding()
        .environment(AppContainer.preview())
}
