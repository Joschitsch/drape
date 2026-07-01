//
//  WardrobeDrawer.swift
//  drape
//
//  The wardrobe browser embedded in the Moodboard's persistent bottom panel.
//  Browse by category and tap to add / swap / remove a piece on the board above
//  — the board stays pinned and visible, so styling feels live and tactile.
//

import SwiftUI
import SwiftData

struct WardrobeDrawer: View {
    let model: MoodboardViewModel
    /// Called when a tile is tapped (parent toggles it on the board and loads
    /// its cut-out).
    let onTap: (Garment) -> Void

    @Query(filter: #Predicate<Garment> { !$0.isArchived }, sort: \Garment.createdAt, order: .reverse)
    private var garments: [Garment]

    @State private var categoryFilter: GarmentCategory?
    @State private var tapTick = 0

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Theme.tileSpacing)]

    private var results: [Garment] {
        guard let categoryFilter else { return garments }
        return garments.filter { $0.category == categoryFilter }
    }

    var body: some View {
        VStack(spacing: 0) {
            categoryBar
            Divider().overlay(Theme.line)
            content
        }
        .sensoryFeedback(.impact(weight: .light), trigger: tapTick)
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                DrapeChip(label: "All", active: categoryFilter == nil) { categoryFilter = nil }
                ForEach(GarmentCategory.allCases) { category in
                    DrapeChip(label: category.displayName, active: categoryFilter == category) {
                        categoryFilter = (categoryFilter == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.vertical, 10)
        }
        .horizontalScrollFade()
    }

    @ViewBuilder
    private var content: some View {
        if results.isEmpty {
            ContentUnavailableView {
                Label("Nothing here yet", image: "drape.wardrobe")
            } description: {
                Text("Add pieces to your wardrobe to style them here.")
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                    ForEach(results) { garment in
                        Button {
                            tapTick += 1
                            onTap(garment)
                        } label: {
                            PickerGarmentTile(garment: garment)
                                .overlay(alignment: .topLeading) { onBoardBadge(garment) }
                        }
                        .buttonStyle(PressableScale(scale: 0.94))
                    }
                }
                .padding(Theme.contentPadding)
            }
        }
    }

    @ViewBuilder
    private func onBoardBadge(_ garment: Garment) -> some View {
        if model.isOnBoard(garment) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.paper, Theme.ink)
                .padding(8)
        }
    }
}

/// A compact picker tile — image + category only, no name or worn-status label,
/// so the drawer reads as a clean grid of pieces to tap in and out.
private struct PickerGarmentTile: View {
    let garment: Garment

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                .shadow(color: Theme.shadow, radius: 11, x: 0, y: 8)

            MonoLabel(garment.category.displayName, size: 10)
                .lineLimit(1)
        }
        .contentShape(Rectangle())
    }
}
