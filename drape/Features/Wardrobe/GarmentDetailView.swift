//
//  GarmentDetailView.swift
//  drape
//
//  Editorial garment detail: hero canvas (tap to enlarge), wear story, the full
//  set of attributes laid out so they're all visible at a glance, the outfits
//  this piece appears in, notes, and the "Wore today" celebration moment.
//

import SwiftUI
import SwiftData

struct GarmentDetailView: View {
    @Bindable var garment: Garment

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var isStyling = false
    @State private var showingZoom = false
    @State private var celebration: CelebrationEntry? = nil

    var body: some View {
        // Deleting the garment detaches its backing data, but SwiftUI may
        // re-evaluate this view once more before the dismissal removes it.
        // Reading a persisted attribute on the detached model would trap, so
        // render nothing the moment the garment is gone.
        if garment.modelContext == nil {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroImage(topInset: proxy.safeAreaInsets.top)

                        VStack(alignment: .leading, spacing: 20) {
                            header
                            wearStory
                            attributes
                            if let notes = garment.notes, !notes.isEmpty {
                                notesCard(notes)
                            }
                            appearsIn
                        }
                        .padding(.horizontal, Theme.contentPadding)
                        .padding(.top, 18)

                        Spacer(minLength: 100)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .scrollBounceBehavior(.always)

                VStack { Spacer(); woreFooter }

                if let entry = celebration {
                    WoreTodayCelebration(
                        garment: entry.garment,
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
            .navigationTitle(garment.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        garment.isFavorite.toggle()
                        try? modelContext.save()
                    } label: {
                        Image(garment.isFavorite ? "drape.heart.fill" : "drape.heart")
                            .foregroundStyle(Theme.ink)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: garment.isFavorite)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { isStyling = true } label: {
                            Label("Style this piece", systemImage: "sparkles")
                        }
                        Button { isEditing = true } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { Task { @MainActor in showDeleteConfirm = true } } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .drapeDeleteConfirmation(
                        title: "Delete \u{201C}\(garment.displayName)\u{201D}?",
                        message: "This removes it from your wardrobe permanently.",
                        isPresented: $showDeleteConfirm
                    ) { delete() }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditGarmentView(garment: garment)
            }
            .sheet(isPresented: $isStyling) {
                StyleThisPieceView(garment: garment)
            }
            .fullScreenCover(isPresented: $showingZoom) {
                ZoomableImageView(assetID: garment.imageAssetID)
            }
        }
    }

    // MARK: - Sections

    private func heroImage(topInset: CGFloat) -> some View {
        Button { showingZoom = true } label: {
            // The garment image is a full-width square (aspectRatio on the image
            // itself, so it never letterboxes). The safe-area inset is added as
            // extra space ABOVE the image, growing the gray strip rather than
            // shrinking the image — so the garment always sits fully below the
            // nav bar. The canvas fills behind and bleeds up under the
            // translucent bar (background to the edge, content within the safe
            // area, per the HIG).
            NormalizedImageView(assetID: garment.imageAssetID, useThumbnail: false)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .padding(.top, topInset)
                .background(AppBackground())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Garment photo")
        .accessibilityHint("Double-tap to enlarge")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            MonoLabel([garment.category.displayName, garment.subcategory]
                .compactMap { $0 }.joined(separator: " · "))
                .padding(.bottom, 2)
            SerifText(garment.displayName, size: 28)
            if let brand = garment.brand, !brand.isEmpty {
                Text(brand)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
    }

    private var wearStory: some View {
        VStack(alignment: .leading, spacing: 5) {
            SerifText(garment.lastWornLabel, size: 17)
            if garment.wearCount > 0 {
                MonoLabel("Worn \(garment.wearCount)×", size: 10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .drapeCard(radius: 14)
    }

    private var attributes: some View {
        FlowLayout(spacing: 8) {
            TagChip(garment.primaryColor.displayName, swatch: garment.displayColor)
            ForEach(attributeTags, id: \.self) { tag in
                TagChip(tag)
            }
        }
    }

    /// Every non-color attribute, in a stable reading order. Color leads the row
    /// separately (it carries a swatch), so it's excluded here.
    private var attributeTags: [String] {
        // Canonicalise styles to the unified vocabulary, de-duplicating so two
        // legacy synonyms (e.g. "classic" + "elegant") don't show twice.
        var seenStyles = Set<Archetype>()
        let styleNames = garment.styles.compactMap { raw -> String? in
            guard let a = Archetype.from(style: raw), seenStyles.insert(a).inserted else { return nil }
            return a.displayName
        }
        return [garment.formality.displayName,
                garment.warmth.displayName + " warmth"]
            + [garment.fit?.displayName].compactMap { $0 }
            + garment.seasons.map(\.displayName)
            + styleNames
    }

    private func notesCard(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel("Note to self", size: 9.5)
            SerifText("\u{201C}\(notes)\u{201D}", size: 17, italic: true)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .drapeCard(radius: 14)
    }

    @ViewBuilder
    private var appearsIn: some View {
        let outfits = garment.outfits.sorted { $0.createdAt > $1.createdAt }
        if !outfits.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                MonoLabel("Appears in \(outfits.count) outfit\(outfits.count == 1 ? "" : "s")")
                VStack(spacing: 0) {
                    ForEach(Array(outfits.enumerated()), id: \.element.id) { idx, outfit in
                        NavigationLink(value: outfit) {
                            OutfitLinkRow(outfit: outfit)
                        }
                        .buttonStyle(.plain)

                        if idx < outfits.count - 1 {
                            Theme.line.frame(height: 0.5).padding(.leading, 78)
                        }
                    }
                }
                .drapeCard(radius: 18)
            }
        }
    }

    private var woreFooter: some View {
        StickyFooter {
            CTAButton(title: "I wore this today") { logWear() }
        }
    }

    // MARK: - Actions

    private func logWear() {
        let isFirst = garment.wearCount == 0
        let event = WearEvent(date: .now, outfit: nil, garments: [garment])
        modelContext.insert(event)
        try? modelContext.save()
        withAnimation {
            celebration = CelebrationEntry(garment: garment, isFirstWear: isFirst, undoEvent: event)
        }
    }

    private func delete() {
        // Dismiss first so this view is on its way out before the model detaches;
        // the body guard above covers any re-evaluation during the dismissal.
        dismiss()
        deleteGarment(garment, context: modelContext, imageStore: container.imageStore)
    }
}

// MARK: - Supporting views

/// A tappable row for an outfit this garment belongs to — lead-garment thumbnail,
/// name and piece count. Mirrors the in-card garment stack used on the outfit
/// screens so the two read as one family.
private struct OutfitLinkRow: View {
    let outfit: Outfit

    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: sortedGarments(outfit.garments).first?.thumbnailAssetID ?? "")
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 4) {
                SerifText(outfit.name, size: 15).lineLimit(1)
                MonoLabel("\(outfit.garments.count) piece\(outfit.garments.count == 1 ? "" : "s")", size: 10)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

// MARK: - Supporting types

private struct CelebrationEntry: Identifiable {
    let id = UUID()
    let garment: Garment
    let isFirstWear: Bool
    let undoEvent: WearEvent
}
