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
    @State private var filter = GarmentFilter()
    @State private var showingFilter = false

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    private var availableCategories: [GarmentCategory] {
        let present = Set(garments.map(\.category))
        return GarmentCategory.allCases.filter { present.contains($0) }
    }

    private var filteredGarments: [Garment] {
        var list = garments
        if let cat = selectedCategory { list = list.filter { $0.category == cat } }
        if favoritesOnly { list = list.filter(\.isFavorite) }
        return list.filter(filter.matches)
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
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Wardrobe")
            .navigationSubtitle("\(garments.count) of \(SubscriptionTier.free.garmentLimit ?? 30) pieces")
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { showingFilter = true } label: {
                        Image(systemName: filter.isActive
                              ? "line.3.horizontal.decrease.circle.fill"
                              : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel(filter.isActive ? "Filter (active)" : "Filter")
                    Button { addTapped() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) { AddGarmentView() }
            .sheet(isPresented: $showingFilter) {
                GarmentFilterSheet(filter: $filter, garments: garments)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            }
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
            .onChange(of: GarmentFacets(garments)) { _, newFacets in
                filter.prune(to: newFacets)
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

                // ── Category chips ───────────────────────────────────
                if availableCategories.count > 1 {
                    filterPills
                        .padding(.horizontal, Theme.contentPadding)
                        .padding(.vertical, 12)
                }

                // ── Active secondary filter chips ────────────────────
                activeFilterSummary
                    .padding(.horizontal, Theme.contentPadding)

                // ── Grid ─────────────────────────────────────────────
                if filteredGarments.isEmpty {
                    if filter.isActive {
                        ContentUnavailableView {
                            Label("No matches", image: "drape.wardrobe")
                        } description: {
                            Text("No items match these filters.")
                        } actions: {
                            CTAButton(title: "Clear filters") { filter.clear() }
                                .padding(.horizontal, Theme.contentPadding)
                        }
                        .padding(.top, 32)
                    } else {
                        ContentUnavailableView {
                            Label("No \(selectedCategory?.displayName.lowercased() ?? "items") yet",
                                  image: selectedCategory?.iconName ?? "drape.wardrobe")
                        } description: {
                            Text("Add a \(selectedCategory?.displayName.lowercased() ?? "garment") to see it here.")
                        } actions: {
                            Button("Add Item") { addTapped() }.buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 32)
                    }
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

    // MARK: - Active secondary filter summary

    @ViewBuilder
    private var activeFilterSummary: some View {
        let chiplets = summaryChiplets
        if !chiplets.isEmpty {
            FlowLayout(spacing: 8) {
                ForEach(chiplets) { chiplet in
                    Button(action: chiplet.remove) {
                        HStack(spacing: 5) {
                            Text(chiplet.label)
                                .font(Theme.body(12, weight: .medium))
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .foregroundStyle(Theme.paper)
                        .background(Theme.ink, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(chiplet.label) filter")
                }
                Button("Clear all") { filter.clear() }
                    .font(Theme.body(12, weight: .medium))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.vertical, 5)
                    .buttonStyle(.plain)
            }
            .padding(.bottom, 12)
        }
    }

    private struct Chiplet: Identifiable {
        let id: String; let label: String; let remove: () -> Void
    }

    private var summaryChiplets: [Chiplet] {
        var out: [Chiplet] = []
        for c in filter.colors.sorted(by: { $0.displayName < $1.displayName }) {
            out.append(Chiplet(id: "color-\(c.id)", label: c.displayName) { filter.colors.remove(c) })
        }
        for f in filter.formalities.sorted(by: { $0.displayName < $1.displayName }) {
            out.append(Chiplet(id: "form-\(f.id)", label: f.displayName) { filter.formalities.remove(f) })
        }
        for w in filter.warmths.sorted(by: { $0.displayName < $1.displayName }) {
            out.append(Chiplet(id: "warm-\(w.id)", label: w.displayName) { filter.warmths.remove(w) })
        }
        for s in filter.seasons.sorted(by: { $0.displayName < $1.displayName }) {
            out.append(Chiplet(id: "season-\(s.id)", label: s.displayName) { filter.seasons.remove(s) })
        }
        for st in filter.styles.sorted() {
            out.append(Chiplet(id: "style-\(st)", label: st) { filter.styles.remove(st) })
        }
        return out
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your wardrobe is empty", image: "drape.wardrobe")
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
            NormalizedImageView(assetID: garment.thumbnailAssetID)
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
        .drapeCard(radius: 16)
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
