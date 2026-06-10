//
//  OutfitListView.swift
//  drape
//
//  Saved outfits as vertical garment-stack cards. Each row shows garments in
//  layer order (outerwear → top → bottom → footwear → accessory) with portrait
//  thumbnails and an inset separator, consistent with the Style tab cards.
//

import SwiftUI
import SwiftData

struct OutfitListView: View {
    @Query(sort: \Outfit.createdAt, order: .reverse)
    private var outfits: [Outfit]

    @State private var showingBuilder = false

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty { emptyState } else { list }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Outfits")
            .navigationSubtitle("\(outfits.count) look\(outfits.count == 1 ? "" : "s")")
            .navigationDestination(for: Outfit.self)  { OutfitDetailView(outfit: $0) }
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingBuilder) { OutfitBuilderView() }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(outfits) { outfit in
                    NavigationLink(value: outfit) {
                        OutfitStackCard(outfit: outfit)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Theme.contentPadding)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No outfits yet", image: "drape.outfits")
        } description: {
            Text("Combine wardrobe items into outfits.")
        } actions: {
            Button("New Outfit") { showingBuilder = true }.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Shared outfit stack card (also used by Style tab)

/// Slot order from head to toe.
let outfitSlotOrder: [GarmentCategory] = [.outerwear, .top, .bottom, .dress, .footwear, .accessory]

func sortedGarments(_ garments: [Garment]) -> [Garment] {
    garments.sorted {
        let a = outfitSlotOrder.firstIndex(of: $0.category) ?? 99
        let b = outfitSlotOrder.firstIndex(of: $1.category) ?? 99
        return a < b
    }
}

struct OutfitStackCard: View {
    let outfit: Outfit

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ───────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline) {
                SerifText(outfit.name, size: 18).lineLimit(1)
                Spacer()
                MonoLabel(outfit.occasion.displayName, size: 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().overlay(Theme.line)

            // ── Garment rows ─────────────────────────────────────────
            let sorted = sortedGarments(outfit.garments)
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                GarmentStackRow(garment: garment, compact: true)
                if idx < sorted.count - 1 {
                    HStack { Color.clear.frame(height: 0) }
                        .overlay(alignment: .leading) {
                            Theme.line
                                .frame(height: 0.5)
                                .padding(.leading, 78) // inset past thumbnail
                        }
                }
            }

            Divider().overlay(Theme.line)

            // ── Footer: tags + wear count ────────────────────────────
            HStack {
                MonoLabel(outfit.tags.map { "#\($0)" }.joined(separator: "  "), size: 10)
                Spacer()
                MonoLabel(outfit.wearCount > 0 ? "Worn \(outfit.wearCount)×" : "Never worn", size: 10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .drapeCard(radius: 18)
    }
}

/// A single garment row inside an outfit stack card.
struct GarmentStackRow: View {
    let garment: Garment
    var compact: Bool = true

    private let thumbW: CGFloat = 48
    private let thumbH: CGFloat = 48

    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(width: thumbW, height: thumbH)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                SerifText(garment.displayName, size: 15).lineLimit(1)
                MonoLabel(garment.category.displayName, size: 10)
            }

            Spacer()

            Circle()
                .fill(garment.displayColor)
                .frame(width: 12, height: 12)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
    }
}

#Preview {
    OutfitListView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
