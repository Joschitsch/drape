//
//  OutfitDetailView.swift
//  drape
//
//  Full outfit view with a vertical garment stack, wear logging, and the
//  "Wore today" celebration moment.
//

import SwiftUI
import SwiftData
import UIKit

struct OutfitDetailView: View {
    @Bindable var outfit: Outfit
    let zoomNamespace: Namespace.ID

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var celebration: OutfitCelebration? = nil
    @State private var tappedGarment: Garment? = nil
    @State private var shareImage: SharedImage? = nil

    private var lastWorn: Date? { outfit.wearEvents.map(\.date).max() }

    private func relativeDay(_ date: Date) -> String {
        let days = Int(Date.now.timeIntervalSince(date) / 86_400)
        if days <= 0 { return "today" }
        if days == 1 { return "yesterday" }
        return "\(days) days ago"
    }

    private var kickerText: String {
        // Once worn, the last-worn date is more useful than the saved date.
        if outfit.wearCount > 0, let last = lastWorn {
            return "\(outfit.occasion.displayName) · worn \(outfit.wearCount)× · last worn \(relativeDay(last))"
        }
        return "\(outfit.occasion.displayName) · saved \(relativeDay(outfit.createdAt)) · not worn yet"
    }

    var body: some View {
        // Deleting the outfit detaches its backing data, but SwiftUI may
        // re-evaluate this view once more before the navigation pop removes it.
        // Reading a persisted attribute (occasion, name…) on the detached model
        // would trap, so render nothing the moment the outfit is gone.
        if outfit.modelContext == nil {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        ZStack {
            // ── Read-only collage fills between nav bar and footer ────
            VStack(spacing: 0) {
                MoodboardThumbnail(
                    garments: outfit.garments,
                    useFullResolution: true,
                    onTapPiece: { tappedGarment = $0 }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                woreFooter
            }

            // ── Celebration overlay ───────────────────────────────────
            if let entry = celebration {
                WoreTodayCelebration(
                    garment: entry.leadGarment,
                    isFirstWear: entry.isFirstWear,
                    onDismiss: { withAnimation { celebration = nil } },
                    onUndo: {
                        modelContext.delete(entry.undoEvent)
                        try? modelContext.save()
                        withAnimation { celebration = nil }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(outfit.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $tappedGarment) { garment in
            GarmentDetailView(garment: garment)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { share() } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share outfit")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) { Task { @MainActor in showDeleteConfirm = true } } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                } label: { Image(systemName: "ellipsis.circle") }
                .drapeDeleteConfirmation(
                    title: "Delete \u{201C}\(outfit.name)\u{201D}?",
                    message: "The garments in it stay in your wardrobe.",
                    isPresented: $showDeleteConfirm
                ) { delete() }
            }
        }
        .sheet(item: $shareImage) { item in
            ShareSheet(items: [item.image])
        }
        .sheet(isPresented: $isEditing) {
            if FeatureFlags.useMoodboardBuilder { MoodboardView(editing: outfit) }
            else { OutfitBuilderView(editing: outfit) }
        }
    }

    private func share() {
        let garments = outfit.garments
        Task {
            if let image = await MoodboardRenderer.renderImage(garments: garments, container: container) {
                shareImage = SharedImage(image: image)
            }
        }
    }

    // MARK: - Footer

    private var woreFooter: some View {
        StickyFooter {
            CTAButton(title: "I wore this today") { logWear() }
        }
    }

    // MARK: - Actions

    private func logWear() {
        let isFirst = outfit.wearCount == 0
        let event = WearEvent(date: .now, outfit: outfit, garments: outfit.garments)
        modelContext.insert(event)
        try? modelContext.save()
        let lead = sortedGarments(outfit.garments).first ?? outfit.garments[0]
        withAnimation {
            celebration = OutfitCelebration(leadGarment: lead, isFirstWear: isFirst, undoEvent: event)
        }
    }

    private func delete() {
        // Pop first so this view is on its way out before the model detaches;
        // the body guard above covers any re-evaluation during the pop.
        dismiss()
        deleteOutfit(outfit, context: modelContext)
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
