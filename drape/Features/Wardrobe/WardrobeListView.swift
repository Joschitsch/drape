//
//  WardrobeListView.swift
//  drape
//
//  The wardrobe grid: browse, add (with free-tier cap), and open item details.
//  Includes the "Honest Mirror" nudge for long-neglected favorites.
//

import SwiftUI
import SwiftData

struct WardrobeListView: View {
    @Query(
        filter: #Predicate<Garment> { !$0.isArchived },
        sort: \Garment.createdAt, order: .reverse
    )
    private var garments: [Garment]

    @Environment(AppContainer.self) private var container

    @State private var showingAdd = false
    @State private var showLimitAlert = false
    @State private var showingPaywall = false
    @State private var selectedCategory: GarmentCategory? = nil
    @State private var favoritesOnly = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    private var availableCategories: [GarmentCategory] {
        let present = Set(garments.map(\.category))
        return GarmentCategory.allCases.filter { present.contains($0) }
    }

    private var filteredGarments: [Garment] {
        var list = garments
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        if favoritesOnly { list = list.filter(\.isFavorite) }
        return list
    }

    /// Most-neglected favorited garment (60+ days without a wear).
    private var neglectedFavorite: Garment? {
        garments
            .filter { g in
                guard g.isFavorite else { return false }
                guard let days = g.daysSinceLastWear else { return true } // never worn
                return days > 60
            }
            .max { ($0.daysSinceLastWear ?? Int.max) < ($1.daysSinceLastWear ?? Int.max) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    emptyState
                } else {
                    scrollContent
                }
            }
            .navigationTitle("Wardrobe")
            .navigationSubtitle("\(garments.count) of \(SubscriptionTier.free.garmentLimit ?? 30) pieces")
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addTapped() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddGarmentView() }
            .alert("Free limit reached", isPresented: $showLimitAlert) {
                Button("Upgrade to Pro") { showingPaywall = true }
                Button("Maybe Later", role: .cancel) {}
            } message: {
                Text("You've reached the \(SubscriptionTier.free.garmentLimit ?? 0)-item limit. Upgrade to Pro for an unlimited wardrobe.")
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView().environment(container.entitlements)
            }
            .onChange(of: availableCategories) {
                if let sel = selectedCategory, !availableCategories.contains(sel) {
                    selectedCategory = nil
                }
            }
        }
    }

    // MARK: - Content

    private var scrollContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ── Honest Mirror nudge ──────────────────────────────
                if let g = neglectedFavorite,
                   selectedCategory == nil,
                   !favoritesOnly {
                    NavigationLink(value: g) {
                        HonestMirrorNudge(garment: g)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.contentPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                }

                // ── Filter chips ─────────────────────────────────────
                if availableCategories.count > 1 {
                    filterPills
                        .padding(.horizontal, Theme.contentPadding)
                        .padding(.vertical, 12)
                }

                // ── Grid ─────────────────────────────────────────────
                if filteredGarments.isEmpty {
                    ContentUnavailableView {
                        Label("No \(selectedCategory?.displayName.lowercased() ?? "items") yet",
                              systemImage: selectedCategory?.systemImage ?? "tshirt")
                    } description: {
                        Text("Add a \(selectedCategory?.displayName.lowercased() ?? "garment") to see it here.")
                    } actions: {
                        Button("Add Item") { addTapped() }.buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 32)
                } else {
                    LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                        ForEach(filteredGarments) { garment in
                            NavigationLink(value: garment) {
                                GarmentTile(garment: garment)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.contentPadding)
                }
            }
        }
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", active: selectedCategory == nil && !favoritesOnly) {
                    selectedCategory = nil; favoritesOnly = false
                }
                ForEach(availableCategories) { cat in
                    chip(label: cat.displayName, active: selectedCategory == cat && !favoritesOnly) {
                        selectedCategory = selectedCategory == cat ? nil : cat
                        favoritesOnly = false
                    }
                }
                chip(label: "Favorites", active: favoritesOnly) {
                    favoritesOnly.toggle(); selectedCategory = nil
                }
            }
        }
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        DrapeChip(label: label, active: active, small: true, action: action)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your wardrobe is empty", systemImage: "tshirt")
        } description: {
            Text("Add your clothes to start building outfits.")
        } actions: {
            Button("Add Item") { addTapped() }.buttonStyle(.borderedProminent)
        }
    }

    private func addTapped() {
        if container.entitlements.canAddGarment(currentCount: garments.count) {
            showingAdd = true
        } else {
            showLimitAlert = true
        }
    }
}

// MARK: - Honest Mirror nudge card

private struct HonestMirrorNudge: View {
    let garment: Garment

    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category, colorTag: garment.primaryColor)
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                MonoLabel("A quiet reminder", size: 9.5)
                Text(reminderText)
                    .font(Theme.body(13.5))
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Theme.inkFaint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, lineWidth: 0.5)
        )
    }

    private var reminderText: AttributedString {
        var s = AttributedString("You haven't worn the ")
        var name = AttributedString(garment.displayName.lowercased())
        name.font = Theme.body(13.5, weight: .semibold)
        s += name
        s += AttributedString(" \(neglectPhrase(garment)).")
        return s
    }

    private func neglectPhrase(_ g: Garment) -> String {
        guard let days = g.daysSinceLastWear else { return "— it's never been worn" }
        if days > 60 {
            let months = max(1, days / 30)
            return "in \(months) \(months == 1 ? "month" : "months")"
        }
        return "\(days) days ago"
    }
}

#Preview {
    WardrobeListView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
