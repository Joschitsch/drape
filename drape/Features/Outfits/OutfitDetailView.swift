//
//  OutfitDetailView.swift
//  drape
//
//  Full outfit view with a vertical garment stack, wear logging, and the
//  "Wore today" celebration moment.
//

import SwiftUI
import SwiftData

struct OutfitDetailView: View {
    @Bindable var outfit: Outfit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var celebration: OutfitCelebration? = nil

    private var lastWorn: Date? { outfit.wearEvents.map(\.date).max() }

    private var kickerText: String {
        let days = Int(Date.now.timeIntervalSince(outfit.createdAt) / 86_400)
        let saved = days <= 0 ? "saved today" : "saved \(days)d ago"
        let worn = outfit.wearCount > 0 ? "worn \(outfit.wearCount)×" : "never worn"
        return "\(outfit.occasion.displayName) · \(saved) · \(worn)"
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // ── Kicker ───────────────────────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        MonoLabel(kickerText)
                        SerifText(outfit.name, size: 28)
                    }

                    // ── Garment stack (larger thumbnails) ────────────
                    VStack(spacing: 0) {
                        let sorted = sortedGarments(outfit.garments)
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                            NavigationLink(value: garment) {
                                DetailGarmentRow(garment: garment)
                            }
                            .buttonStyle(.plain)

                            if idx < sorted.count - 1 {
                                Theme.line.frame(height: 0.5).padding(.leading, 96)
                            }
                        }
                    }
                    .drapeCard(radius: 18)

                    Spacer(minLength: 120)
                }
                .padding(Theme.contentPadding)
            }
            .scrollIndicators(.hidden)

            // ── Sticky footer ────────────────────────────────────────
            VStack {
                Spacer()
                woreFooter
            }

            // ── Celebration overlay ───────────────────────────────────
            if let entry = celebration {
                WoreTodayCelebration(
                    garment: entry.leadGarment,
                    isFirstWear: entry.isFirstWear,
                    onDismiss: { withAnimation { celebration = nil } }
                )
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .navigationTitle(outfit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { isEditing = true } label: {
                        Label("Edit", systemImage: "pencil")
                    }
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
        .sheet(isPresented: $isEditing) { OutfitBuilderView(editing: outfit) }
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
            celebration = OutfitCelebration(leadGarment: lead, isFirstWear: isFirst)
        }
    }

    private func delete() {
        deleteOutfit(outfit, context: modelContext)
        dismiss()
    }
}

// MARK: - Supporting types

private struct OutfitCelebration: Identifiable {
    let id = UUID()
    let leadGarment: Garment
    let isFirstWear: Bool
}
