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
                        if !outfit.tags.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(outfit.tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(Theme.body(12.5, weight: .medium))
                                        .foregroundStyle(Theme.inkSoft)
                                        .padding(.horizontal, 9).padding(.vertical, 5)
                                        .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                                }
                            }
                        }
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
                                HStack { Color.clear.frame(height: 0) }
                                    .overlay(alignment: .leading) {
                                        Theme.line.frame(height: 0.5).padding(.leading, 96)
                                    }
                            }
                        }
                    }
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.5))

                    Spacer(minLength: 80)
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
                    Button("Edit") { isEditing = true }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .sheet(isPresented: $isEditing) { OutfitBuilderView(editing: outfit) }
        .confirmationDialog("Delete this outfit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Footer

    private var woreFooter: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, Color(UIColor.systemBackground)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 28)
            Button {
                logWear()
            } label: {
                Text("I wore this today")
                    .font(Theme.body(17, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.ink)
                    .foregroundStyle(Theme.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.bottom, 24)
            .background(Color(UIColor.systemBackground))
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
        modelContext.delete(outfit)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Large garment row for detail view

private struct DetailGarmentRow: View {
    let garment: Garment

    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category, colorTag: garment.primaryColor)
                .frame(width: 66, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(garment.category.displayName, size: 8.5)
                SerifText(garment.displayName, size: 16).lineLimit(1)
                if let brand = garment.brand, !brand.isEmpty {
                    Text(brand).font(Theme.body(12.5)).foregroundStyle(Theme.inkSoft)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                Circle()
                    .fill(garment.primaryColor.color)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// MARK: - Supporting types

private struct OutfitCelebration: Identifiable {
    let id = UUID()
    let leadGarment: Garment
    let isFirstWear: Bool
}
