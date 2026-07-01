//
//  OutfitListView.swift
//  drape
//
//  Saved outfits as an editorial Cover Flow gallery: one collage large and
//  centred, neighbours peeking with depth. The focused outfit's name fades in
//  below the gallery; tapping it reveals occasion + piece count, and a control
//  zone offers share / edit / delete / wore-today.
//

import SwiftUI
import SwiftData
import UIKit

struct OutfitListView: View {
    @Query(sort: \Outfit.createdAt, order: .reverse)
    private var outfits: [Outfit]

    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingBuilder = false
    @State private var outfitToEdit: Outfit? = nil
    @State private var outfitToDelete: Outfit? = nil
    @State private var shareImage: SharedImage? = nil
    @State private var sharingID: Outfit.ID? = nil
    @State private var celebration: OutfitCelebration? = nil

    @State private var focusedID: Outfit.ID? = nil
    @State private var metadataExpanded = false
    @State private var tappedGarment: Garment? = nil

    private var focusedOutfit: Outfit? {
        guard let focusedID else { return outfits.first }
        return outfits.first { $0.id == focusedID } ?? outfits.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if outfits.isEmpty { emptyState } else { content }
                }

                if let entry = celebration {
                    WoreTodayCelebration(
                        garment: entry.leadGarment,
                        isFirstWear: entry.isFirstWear,
                        onDismiss: { withAnimation { celebration = nil } },
                        onUndo: {
                            undoWearEvent(entry.undoEvent, context: modelContext)
                            withAnimation { celebration = nil }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle("Outfits")
            .navigationSubtitle("\(outfits.count) look\(outfits.count == 1 ? "" : "s")")
            .navigationDestination(item: $tappedGarment) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                if FeatureFlags.useMoodboardBuilder { MoodboardView() }
                else { OutfitBuilderView() }
            }
            .sheet(item: $outfitToEdit) { outfit in
                if FeatureFlags.useMoodboardBuilder { MoodboardView(editing: outfit) }
                else { OutfitBuilderView(editing: outfit) }
            }
            .sheet(item: $shareImage) { item in
                ShareSheet(items: [item.image])
            }
            .drapeDeleteConfirmation(
                title: "Delete \u{201C}\(outfitToDelete?.name ?? "")\u{201D}?",
                message: "The garments in it stay in your wardrobe.",
                isPresented: Binding(
                    get: { outfitToDelete != nil },
                    set: { if !$0 { outfitToDelete = nil } }
                )
            ) {
                if let o = outfitToDelete {
                    deleteOutfit(o, context: modelContext)
                    outfitToDelete = nil
                }
            }
        }
    }

    // MARK: - Content

    private var content: some View {
        VStack(spacing: 0) {
            CoverFlowGallery(items: outfits, selection: $focusedID, itemWidthFraction: 0.6) { outfit in
                outfitItem(outfit)
            }
            .frame(maxHeight: .infinity)

            focusedPanel
                .animation(.drapeContent, value: focusedID)
        }
        .onAppear { syncFocus() }
        .onChange(of: outfits.map(\.id)) { syncFocus() }
        .onChange(of: focusedID) { metadataExpanded = false }
    }

    @ViewBuilder
    private func outfitItem(_ outfit: Outfit) -> some View {
        // The collage can briefly outlive its outfit during a delete (the @Query
        // updates a beat before SwiftUI drops the view); reading garments on the
        // detached model would trap, so render nothing the moment it's gone.
        if outfit.modelContext == nil {
            Color.clear
        } else {
            MoodboardThumbnail(
                garments: outfit.garments,
                useFullResolution: true,
                onTapPiece: { tappedGarment = $0 },
                showsBackground: false,
                fillsContent: true
            )
            .padding(.vertical, 6)
            .accessibilityLabel("\(outfit.name), \(outfit.occasion.displayName)")
        }
    }

    @ViewBuilder
    private var focusedPanel: some View {
        if let o = focusedOutfit, o.modelContext != nil {
            VStack(spacing: 14) {
                Button {
                    withAnimation(.drapeContent) { metadataExpanded.toggle() }
                } label: {
                    VStack(spacing: 5) {
                        SerifText(o.name, size: 24).lineLimit(1)
                        HStack(spacing: 6) {
                            MonoLabel(o.occasion.displayName, size: 10)
                            Image(systemName: metadataExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(Theme.inkFaint)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)

                if metadataExpanded { metadata(o) }

                controlZone(o)
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .id(o.id)
            .transition(.opacity)
        }
    }

    private func metadata(_ o: Outfit) -> some View {
        VStack(spacing: 6) {
            MonoLabel("\(o.occasion.displayName) · \(o.garments.count) piece\(o.garments.count == 1 ? "" : "s")", size: 10)
            if o.wearCount > 0 {
                MonoLabel("Worn \(o.wearCount)×", size: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func controlZone(_ o: Outfit) -> some View {
        // One prominent primary (log a wear — the core ritual), Share as a
        // subordinate icon, and management/destructive actions tucked into the
        // overflow menu so Delete can't be mistapped next to "Wore today".
        HStack(spacing: 12) {
            PrimaryActionButton(title: "Wore today", systemImage: "checkmark") { logWear(o) }
            CircleIconButton(systemName: "square.and.arrow.up", accessibilityLabel: "Share outfit",
                             isLoading: sharingID == o.id) { share(o) }
            CircleMenuButton(accessibilityLabel: "More actions") {
                Button { outfitToEdit = o } label: { Label("Edit", systemImage: "pencil") }
                Button(role: .destructive) { outfitToDelete = o } label: { Label("Delete", systemImage: "trash") }
            }
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

    // MARK: - Actions

    private func syncFocus() {
        if focusedID == nil || !outfits.contains(where: { $0.id == focusedID }) {
            focusedID = outfits.first?.id
        }
    }

    private func share(_ outfit: Outfit) {
        guard sharingID == nil else { return }   // ignore repeat taps while rendering
        let garments = outfit.garments
        let scheme = colorScheme
        sharingID = outfit.id
        Task {
            let image = await MoodboardRenderer.renderImage(garments: garments, container: container, colorScheme: scheme)
            sharingID = nil
            if let image { shareImage = SharedImage(image: image) }
        }
    }

    private func logWear(_ outfit: Outfit) {
        guard let lead = sortedGarments(outfit.garments).first else { return }
        let isFirst = outfit.wearCount == 0
        let event = WearEvent(date: .now, outfit: outfit, garments: outfit.garments)
        modelContext.insert(event)
        try? modelContext.save()
        withAnimation {
            celebration = OutfitCelebration(leadGarment: lead, isFirstWear: isFirst, undoEvent: event)
        }
    }
}

// MARK: - Supporting types

private struct OutfitCelebration: Identifiable {
    let id = UUID()
    let leadGarment: Garment
    let isFirstWear: Bool
    let undoEvent: WearEvent
}

/// Wraps a rendered collage image so it can drive `.sheet(item:)`.
private struct SharedImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Shared outfit ordering (used by Style + detail screens)

/// Slot order from head to toe.
let outfitSlotOrder: [GarmentCategory] = [.outerwear, .top, .bottom, .dress, .footwear, .accessory]

func sortedGarments(_ garments: [Garment]) -> [Garment] {
    garments.sorted {
        let a = outfitSlotOrder.firstIndex(of: $0.category) ?? 99
        let b = outfitSlotOrder.firstIndex(of: $1.category) ?? 99
        return a < b
    }
}

/// A single garment row inside an outfit stack (used by Style This Piece).
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
