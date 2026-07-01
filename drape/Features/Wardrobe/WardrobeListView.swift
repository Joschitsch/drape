//
//  WardrobeListView.swift
//  drape
//
//  The wardrobe: an editorial Cover Flow gallery (default) or the classic grid,
//  toggleable and remembered across launches. The category filter bar stays
//  pinned above the content in both modes. Includes the "Honest Mirror" nudge
//  for long-neglected favorites (grid mode).
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
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var showLimitAlert = false
    @State private var showingPaywall = false
    @State private var selectedCategory: GarmentCategory? = nil
    @State private var favoritesOnly = false
    @State private var filter = GarmentFilter()
    @State private var showingFilter = false
    @State private var garmentToEdit: Garment? = nil
    @State private var garmentToDelete: Garment? = nil
    @State private var garmentToStyle: Garment? = nil
    @State private var selectedGarment: Garment? = nil
    @Namespace private var zoomNamespace

    /// Cover Flow is the default; the choice persists across launches.
    @AppStorage("wardrobeCoverFlow") private var coverFlow = true
    /// The garment snapped to centre in the gallery (drives the name + panel).
    @State private var focusedID: Garment.ID? = nil
    @State private var metadataExpanded = false
    @State private var celebration: WardrobeCelebration? = nil

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

    private var focusedGarment: Garment? {
        guard let focusedID else { return filteredGarments.first }
        return filteredGarments.first { $0.id == focusedID } ?? filteredGarments.first
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

    private var subtitleText: String {
        if let limit = container.entitlements.tier.garmentLimit {
            return "\(garments.count) of \(limit) pieces"
        }
        return "\(garments.count) piece\(garments.count == 1 ? "" : "s")"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if garments.isEmpty {
                        emptyState
                    } else {
                        mainContent
                    }
                }

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
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle("Wardrobe")
            .navigationSubtitle(subtitleText)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        withAnimation(.drapeContent) { coverFlow.toggle() }
                    } label: {
                        Image(systemName: coverFlow ? "square.grid.2x2" : "rectangle.stack")
                    }
                    .accessibilityLabel(coverFlow ? "Grid view" : "Gallery view")
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
            .sheet(item: $garmentToEdit) { EditGarmentView(garment: $0) }
            .sheet(item: $garmentToStyle) { StyleThisPieceView(garment: $0) }
            .drapeDeleteConfirmation(
                title: "Delete \u{201C}\(garmentToDelete?.displayName ?? "")\u{201D}?",
                message: "This removes it from your wardrobe permanently.",
                isPresented: Binding(
                    get: { garmentToDelete != nil },
                    set: { if !$0 { garmentToDelete = nil } }
                )
            ) {
                if let g = garmentToDelete {
                    deleteGarment(g, context: modelContext, imageStore: container.imageStore)
                    garmentToDelete = nil
                }
            }
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
            .fullScreenCover(item: $selectedGarment) { garment in
                NavigationStack {
                    GarmentDetailView(garment: garment)
                        .navigationDestination(for: Outfit.self) {
                            OutfitDetailView(outfit: $0, zoomNamespace: zoomNamespace)
                        }
                        .navigationDestination(for: Garment.self) {
                            GarmentDetailView(garment: $0)
                        }
                }
                .navigationTransition(.zoom(sourceID: garment.id, in: zoomNamespace))
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

    private var mainContent: some View {
        VStack(spacing: 0) {
            pinnedFilterBar
            if coverFlow { coverFlowContent } else { gridContent }
        }
    }

    // ── Pinned filter bar (both modes) ───────────────────────────────────────

    private var pinnedFilterBar: some View {
        VStack(spacing: 0) {
            if availableCategories.count > 1 {
                filterPills
                    .padding(.horizontal, Theme.contentPadding)
                    .padding(.vertical, 12)
            }
            activeFilterSummary
                .padding(.horizontal, Theme.contentPadding)
        }
    }

    // ── Cover Flow ───────────────────────────────────────────────────────────

    private var coverFlowContent: some View {
        VStack(spacing: 0) {
            if filteredGarments.isEmpty {
                emptyFilterState
                    .padding(.top, 32)
                Spacer(minLength: 0)
            } else {
                CoverFlowGallery(items: filteredGarments, selection: $focusedID) { garment in
                    galleryItem(garment)
                }
                .frame(maxHeight: .infinity)

                focusedPanel
                    .animation(.drapeContent, value: focusedID)
            }
        }
        .onAppear { syncFocus() }
        .onChange(of: filteredGarments.map(\.id)) { syncFocus() }
        .onChange(of: focusedID) { metadataExpanded = false }
    }

    private func galleryItem(_ garment: Garment) -> some View {
        // Scales on press (no opacity dim) so it reads as tappable; no
        // `.contextMenu` — the focused panel below already exposes Favorite /
        // Edit / Delete via the "⋯" overflow, so the long-press is redundant
        // here. The grid tiles keep their context menu (no overflow).
        Button { selectedGarment = garment } label: {
            NormalizedImageView(assetID: garment.imageAssetID, useThumbnail: false)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableScale(scale: 0.96))
        .matchedTransitionSource(id: garment.id, in: zoomNamespace)
        .accessibilityLabel(garment.displayName)
        .accessibilityHint("Double-tap to open")
    }

    @ViewBuilder
    private var focusedPanel: some View {
        if let g = focusedGarment {
            VStack(spacing: 14) {
                Button {
                    withAnimation(.drapeContent) { metadataExpanded.toggle() }
                } label: {
                    VStack(spacing: 5) {
                        SerifText(g.displayName, size: 24).lineLimit(1)
                        HStack(spacing: 6) {
                            MonoLabel([g.category.displayName, g.subcategory]
                                .compactMap { $0 }.joined(separator: " · "), size: 10)
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

                if metadataExpanded { metadata(g) }

                controlZone(g)
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.top, 6)
            .padding(.bottom, 14)
            .id(g.id)
            .transition(.opacity)
        }
    }

    private func metadata(_ g: Garment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let brand = g.brand, !brand.isEmpty {
                Text(brand).font(Theme.body(14)).foregroundStyle(Theme.inkSoft)
            }
            MonoLabel(g.lastWornLabel, size: 10)
            FlowLayout(spacing: 8) {
                TagChip(g.primaryColor.displayName, swatch: g.displayColor)
                ForEach(metadataTags(g), id: \.self) { TagChip($0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// Every non-color attribute, in a stable reading order (mirrors the detail
    /// view). Color leads the row separately since it carries a swatch.
    private func metadataTags(_ g: Garment) -> [String] {
        var seenStyles = Set<Archetype>()
        let styleNames = g.styles.compactMap { raw -> String? in
            guard let a = Archetype.from(style: raw), seenStyles.insert(a).inserted else { return nil }
            return a.displayName
        }
        return [g.formality.displayName, g.warmth.displayName + " warmth"]
            + [g.fit?.displayName].compactMap { $0 }
            + g.seasons.map(\.displayName)
            + styleNames
    }

    private func controlZone(_ g: Garment) -> some View {
        // "Style This Piece" is the forward action this screen is built around →
        // the primary. Wore-today stays a subordinate icon; Edit/Delete move into
        // the overflow so the destructive action is contained and separated.
        HStack(spacing: 12) {
            PrimaryActionButton(title: "Style This Piece", systemImage: "sparkles") { garmentToStyle = g }
            CircleIconButton(systemName: "checkmark.circle", accessibilityLabel: "Wore today") { logWear(g) }
            CircleMenuButton(accessibilityLabel: "More actions") {
                Button {
                    g.isFavorite.toggle()
                    try? modelContext.save()
                } label: {
                    Label(g.isFavorite ? "Unfavorite" : "Favorite",
                          systemImage: g.isFavorite ? "heart.slash" : "heart")
                }
                Button { garmentToEdit = g } label: { Label("Edit", systemImage: "pencil") }
                Divider()
                Button(role: .destructive) { garmentToDelete = g } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    // ── Grid ───────────────────────────────────────────────────────────────

    private var gridContent: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let g = neglectedFavorite,
                   selectedCategory == nil,
                   !favoritesOnly {
                    Button { selectedGarment = g } label: {
                        HonestMirrorNudge(garment: g)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.contentPadding)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                }

                if filteredGarments.isEmpty {
                    emptyFilterState
                        .padding(.top, 32)
                } else {
                    LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                        ForEach(filteredGarments) { garment in
                            Button { selectedGarment = garment } label: {
                                GarmentTile(garment: garment)
                            }
                            .buttonStyle(PressableScale(scale: 0.94))
                            .matchedTransitionSource(id: garment.id, in: zoomNamespace)
                            .contextMenu { contextMenu(garment) }
                        }
                    }
                    .padding(Theme.contentPadding)
                }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(_ garment: Garment) -> some View {
        Button {
            garment.isFavorite.toggle()
            try? modelContext.save()
        } label: {
            Label(
                garment.isFavorite ? "Unfavorite" : "Favorite",
                systemImage: garment.isFavorite ? "heart.slash" : "heart"
            )
        }
        Button { garmentToEdit = garment } label: {
            Label("Edit", systemImage: "pencil")
        }
        Divider()
        Button(role: .destructive) {
            garmentToDelete = garment
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    @ViewBuilder
    private var emptyFilterState: some View {
        if filter.isActive {
            ContentUnavailableView {
                Label("No matches", image: "drape.wardrobe")
            } description: {
                Text("No items match these filters.")
            } actions: {
                CTAButton(title: "Clear filters") { filter.clear() }
                    .padding(.horizontal, Theme.contentPadding)
            }
        } else {
            ContentUnavailableView {
                Label("No \(selectedCategory?.displayName.lowercased() ?? "items") yet",
                      image: selectedCategory?.iconName ?? "drape.wardrobe")
            } description: {
                Text("Add a \(selectedCategory?.displayName.lowercased() ?? "garment") to see it here.")
            } actions: {
                Button("Add Item") { addTapped() }.buttonStyle(.borderedProminent)
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
        .horizontalScrollFade()
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
                            if let tag = chiplet.swatch {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().strokeBorder(Theme.paper.opacity(0.5), lineWidth: 0.5))
                            } else {
                                Text(chiplet.label)
                                    .font(Theme.body(12, weight: .medium))
                            }
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
        let id: String; let label: String; var swatch: ColorTag? = nil; let remove: () -> Void
    }

    private var summaryChiplets: [Chiplet] {
        var out: [Chiplet] = []
        for c in filter.colors.sorted(by: { $0.displayName < $1.displayName }) {
            out.append(Chiplet(id: "color-\(c.id)", label: c.displayName, swatch: c) { filter.colors.remove(c) })
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

    // MARK: - Actions

    private func syncFocus() {
        if focusedID == nil || !filteredGarments.contains(where: { $0.id == focusedID }) {
            focusedID = filteredGarments.first?.id
        }
    }

    private func logWear(_ g: Garment) {
        let isFirst = g.wearCount == 0
        let event = WearEvent(date: .now, outfit: nil, garments: [g])
        modelContext.insert(event)
        try? modelContext.save()
        withAnimation {
            celebration = WardrobeCelebration(garment: g, isFirstWear: isFirst, undoEvent: event)
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

// MARK: - Supporting types

private struct WardrobeCelebration: Identifiable {
    let id = UUID()
    let garment: Garment
    let isFirstWear: Bool
    let undoEvent: WearEvent
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
