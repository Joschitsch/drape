//
//  GarmentTile.swift
//  drape
//
//  Square wardrobe-grid cell for a single garment.
//  Visual language: tonal canvas placeholder, editorial name, "worn X days ago"
//  timestamp, and a subtle ink dot for favorites.
//

import SwiftUI

struct GarmentTile: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            // ── Image / canvas ───────────────────────────────────────
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)   // square garment images
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .shadow(color: Theme.shadow, radius: 11, x: 0, y: 8)
                .overlay(alignment: .topTrailing) {
                    if garment.isFavorite {
                        Circle()
                            .fill(Theme.ink)
                            .frame(width: 8, height: 8)
                            .padding(4)
                            .background(Theme.paper.opacity(0.7), in: Circle())
                            .padding(6)
                    }
                }

            // ── Name ─────────────────────────────────────────────────
            SerifText(garment.displayName, size: 16)
                .lineLimit(1)

            // ── Last-worn timestamp ───────────────────────────────────
            MonoLabel(garment.lastWornLabel, size: 10)
                .lineLimit(1)
        }
    }
}

// MARK: - Garment helpers used by tiles and detail

extension Garment {
    /// Graceful name: stored name → category display name fallback.
    var displayName: String { name ?? category.displayName }

    /// Human-readable last-worn string derived from wear history.
    var lastWornLabel: String {
        guard let last = wearEvents.map(\.date).max() else { return "Never worn" }
        let days = Int(Date.now.timeIntervalSince(last) / 86_400)
        if days == 0 { return "Worn today" }
        if days == 1 { return "Worn yesterday" }
        if days < 14 { return "Worn \(days) days ago" }
        if days < 60 { return "Worn \(days / 7) weeks ago" }
        let months = Int(days / 30)
        return "Last worn \(months) \(months == 1 ? "month" : "months") ago"
    }

    /// Days since last wear (nil if never worn).
    var daysSinceLastWear: Int? {
        guard let last = wearEvents.map(\.date).max() else { return nil }
        return Int(Date.now.timeIntervalSince(last) / 86_400)
    }
}
