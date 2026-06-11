//
//  GarmentDetailView.swift
//  drape
//
//  Editorial garment detail: hero canvas, story card, attribute tags, notes,
//  and the "Wore today" celebration moment.
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
    @State private var celebration: CelebrationEntry? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage
                        .padding(.top, 8)
                        .padding(.bottom, 18)

                    kicker
                    nameAndBrand
                    storyCard
                    attributeTags
                    if let notes = garment.notes, !notes.isEmpty {
                        notesCard(notes)
                    }

                    Spacer(minLength: 100) // room for sticky footer
                }
            }
            .scrollIndicators(.hidden)

            // ── Sticky "Wore today" footer ───────────────────────────
            VStack {
                Spacer()
                woreFooter
            }

            // ── Celebration overlay ──────────────────────────────────
            if let entry = celebration {
                WoreTodayCelebration(
                    garment: entry.garment,
                    isFirstWear: entry.isFirstWear,
                    onDismiss: { withAnimation { celebration = nil } }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationTitle(garment.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    garment.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Image(garment.isFavorite ? "drape.heart.fill" : "drape.heart")
                        .foregroundStyle(Theme.ink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
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
    }

    // MARK: - Sections

    private var heroImage: some View {
        ZStack {
            Theme.surface
            garment.displayColor.opacity(0.18)
            NormalizedImageView(
                assetID: garment.imageAssetID,
                useThumbnail: false
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .aspectRatio(4/5, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Theme.shadow, radius: 20, x: 0, y: 10)
    }

    private var kicker: some View {
        MonoLabel([garment.category.displayName, garment.subcategory]
            .compactMap { $0 }.joined(separator: " · "))
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, 7)
    }

    private var nameAndBrand: some View {
        VStack(alignment: .leading, spacing: 5) {
            SerifText(garment.displayName, size: 28)
            if let brand = garment.brand, !brand.isEmpty {
                Text(brand)
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
    }

    private var storyCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                SerifText(garment.lastWornLabel, size: 17)
                MonoLabel("Worn \(garment.wearCount)× · in \(garment.outfits.count) outfit\(garment.outfits.count == 1 ? "" : "s")", size: 10)
            }
            Spacer()
            Circle()
                .fill(garment.displayColor)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .drapeCard(radius: 14)
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
    }

    private var attributeTags: some View {
        let tags: [String] = [
            garment.primaryColor.displayName,
            garment.formality.displayName,
            garment.warmth.displayName + " warmth",
        ] + garment.seasons.map(\.displayName)
          + garment.styles.map(Style.displayName)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    TagChip(tag)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
        }
        .padding(.bottom, 16)
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
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
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
            celebration = CelebrationEntry(garment: garment, isFirstWear: isFirst)
        }
    }

    private func delete() {
        deleteGarment(garment, context: modelContext, imageStore: container.imageStore)
        dismiss()
    }
}

// MARK: - Supporting types

private struct CelebrationEntry: Identifiable {
    let id = UUID()
    let garment: Garment
    let isFirstWear: Bool
}
