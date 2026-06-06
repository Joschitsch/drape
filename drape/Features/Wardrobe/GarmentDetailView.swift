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
                        .padding(.horizontal, Theme.contentPadding)
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
                    Image(systemName: garment.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(.pink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditGarmentView(garment: garment)
        }
        .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Sections

    private var heroImage: some View {
        NormalizedImageView(
            assetID: garment.imageAssetID,
            category: garment.category,
            colorTag: garment.primaryColor,
            showColorName: true,
            useThumbnail: false
        )
        .aspectRatio(0.926, contentMode: .fit)   // design hero ≈108% tall
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 28, x: 0, y: 14)
    }

    private var kicker: some View {
        Text([garment.category.displayName, garment.styles.first?.displayName]
            .compactMap { $0 }.joined(separator: " · "))
            .font(.caption)
            .foregroundStyle(Theme.inkFaint)
            .kerning(0.5)
            .textCase(.uppercase)
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, 5)
    }

    private var nameAndBrand: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(garment.displayName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.primary)
            if let brand = garment.brand, !brand.isEmpty {
                Text(brand)
                    .font(.subheadline)
                    .foregroundStyle(Theme.inkSoft)
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
    }

    private var storyCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(garment.lastWornLabel)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Text("Worn \(garment.wearCount)× · in \(garment.outfits.count) outfit\(garment.outfits.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
            Spacer()
            Circle()
                .fill(garment.primaryColor.color)
                .frame(width: 28, height: 28)
                .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 0.5))
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
    }

    private var attributeTags: some View {
        let tags: [String] = [
            garment.primaryColor.displayName,
            garment.formality.displayName,
            garment.warmth.displayName + " warmth",
        ] + garment.seasons.map(\.displayName)
          + garment.styles.map(\.displayName)

        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.subheadline)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 0.5))
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
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.line, lineWidth: 0.5))
        .padding(.horizontal, Theme.contentPadding)
        .padding(.bottom, 16)
    }

    private var woreFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, Color(UIColor.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 32)
            Button {
                logWear()
            } label: {
                Text("I wore this today")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.primary)
                    .foregroundStyle(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, 24)
            .background(Color(UIColor.systemBackground))
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
        let ref = ImageAssetReference(
            imageAssetID: garment.imageAssetID,
            thumbnailAssetID: garment.thumbnailAssetID
        )
        modelContext.delete(garment)
        try? modelContext.save()
        let store = container.imageStore
        Task { try? await store.delete(ref) }
        dismiss()
    }
}

// MARK: - Supporting types

private struct CelebrationEntry: Identifiable {
    let id = UUID()
    let garment: Garment
    let isFirstWear: Bool
}
