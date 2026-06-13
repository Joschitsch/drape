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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var celebration: CelebrationEntry? = nil

    /// How far the user has pulled past the top, 0…1 where 1 is the dismiss
    /// threshold. Drives the live scale/fade so the gesture feels committed.
    @State private var pullProgress: CGFloat = 0
    /// Flips true the instant the threshold is crossed — fires the commit haptic.
    @State private var willDismiss = false
    /// Guards against the scroll callback firing `dismiss()` more than once.
    @State private var didDismiss = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroImage(topInset: proxy.safeAreaInsets.top)
                            .padding(.bottom, 18)

                        kicker
                        nameAndBrand
                        storyCard
                        attributeTags
                        if let notes = garment.notes, !notes.isEmpty {
                            notesCard(notes)
                        }

                        Spacer(minLength: 100)
                    }
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .scrollBounceBehavior(.always)
                // The pull tracks the finger 1:1 (no animation here, or it would
                // lag behind the scroll); the spring-back comes from the scroll
                // returning to rest on release.
                .scaleEffect(reduceMotion ? 1 : 1 - pullProgress * 0.04)
                .opacity(reduceMotion ? 1 : 1 - pullProgress * 0.12)
                .onScrollGeometryChange(for: CGFloat.self) { geo in
                    geo.contentOffset.y + geo.contentInsets.top
                } action: { _, distanceFromTop in
                    let progress = min(1, max(0, -distanceFromTop / 90))
                    pullProgress = progress
                    if progress >= 1 {
                        if !willDismiss { willDismiss = true }
                        if !didDismiss {
                            didDismiss = true
                            dismiss()
                        }
                    } else if willDismiss {
                        willDismiss = false
                    }
                }
                .sensoryFeedback(trigger: willDismiss) { _, crossed in
                    crossed ? .impact(weight: .light) : nil
                }

                VStack { Spacer(); woreFooter }

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
    }

    // MARK: - Sections

    private func heroImage(topInset: CGFloat) -> some View {
        ZStack {
            Color(red: 0.95, green: 0.95, blue: 0.97)
            NormalizedImageView(assetID: garment.imageAssetID, useThumbnail: false)
                .padding(.top, topInset)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
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
