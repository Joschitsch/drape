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
    @Namespace private var zoomNamespace

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty { emptyState } else { list }
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle("Outfits")
            .navigationSubtitle("\(outfits.count) look\(outfits.count == 1 ? "" : "s")")
            .navigationDestination(for: Outfit.self)  { OutfitDetailView(outfit: $0, zoomNamespace: zoomNamespace) }
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
                    .navigationTransition(.zoom(sourceID: garment.id, in: zoomNamespace))
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                if FeatureFlags.useMoodboardBuilder { MoodboardView() }
                else { OutfitBuilderView() }
            }
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 18) {
                ForEach(outfits) { outfit in
                    DeletableOutfitCard(outfit: outfit)
                }
            }
            .padding(Theme.contentPadding)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No outfits yet", image: "drape.outfits")
        } description: {
            Text("Save looks from your Style recommendations, or build your own.")
        } actions: {
            CTAButton(title: "New Outfit") { showingBuilder = true }
                .padding(.horizontal, Theme.contentPadding)
        }
    }
}

// MARK: - Deletable outfit card

/// An outfit stack card with a long-press context menu (Delete). The
/// confirmation dialog lives on this view so iOS 26 anchors it to the card
/// being acted on, matching Photos.app behaviour.
private struct DeletableOutfitCard: View {
    let outfit: Outfit

    @Environment(\.modelContext) private var modelContext

    @State private var showingEdit = false
    @State private var showingDelete = false

    var body: some View {
        NavigationLink(value: outfit) {
            OutfitStackCard(outfit: outfit)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                Task { @MainActor in showingEdit = true }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Task { @MainActor in showingDelete = true }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEdit) {
            if FeatureFlags.useMoodboardBuilder { MoodboardView(editing: outfit) }
            else { OutfitBuilderView(editing: outfit) }
        }
        .drapeDeleteConfirmation(
            title: "Delete \u{201C}\(outfit.name)\u{201D}?",
            message: "The garments in it stay in your wardrobe.",
            isPresented: $showingDelete
        ) {
            deleteOutfit(outfit, context: modelContext)
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
        // The card can briefly outlive its outfit: deleting an outfit updates the
        // @Query, but SwiftUI may re-evaluate this card once more before dropping
        // it from the list. The model's backing data is detached by then, so
        // reading a persisted attribute (occasion, name…) would trap. Bail out.
        if outfit.modelContext == nil {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
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

            // ── Collage preview ──────────────────────────────────────
            MoodboardThumbnail(garments: outfit.garments)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()

            Divider().overlay(Theme.line)

            // ── Footer: wear count ───────────────────────────────────
            HStack {
                MonoLabel(outfit.wearCount > 0 ? "Worn \(outfit.wearCount)×" : "Not worn yet", size: 10)
                Spacer()
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
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
