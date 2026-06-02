//
//  WardrobeListView.swift
//  drape
//
//  The wardrobe grid: browse, add (with free-tier cap), and open item details.
//

import SwiftUI
import SwiftData

struct WardrobeListView: View {
    /// Live, reactive fetch of non-archived garments, newest first.
    @Query(
        filter: #Predicate<Garment> { !$0.isArchived },
        sort: \Garment.createdAt, order: .reverse
    )
    private var garments: [Garment]

    @Environment(AppContainer.self) private var container

    @State private var showingAdd = false
    @State private var showLimitAlert = false
    /// nil = show all categories.
    @State private var selectedCategory: GarmentCategory? = nil

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    /// Categories present in the wardrobe, in display order.
    private var availableCategories: [GarmentCategory] {
        let present = Set(garments.map(\.category))
        return GarmentCategory.allCases.filter { present.contains($0) }
    }

    /// Garments after applying the active category filter.
    private var filteredGarments: [Garment] {
        guard let cat = selectedCategory else { return garments }
        return garments.filter { $0.category == cat }
    }

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        if availableCategories.count > 1 {
                            filterPills
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .background(.bar)
                            Divider()
                        }
                        if filteredGarments.isEmpty {
                            filteredEmptyState
                        } else {
                            grid
                        }
                    }
                }
            }
            .navigationTitle("Wardrobe")
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addTapped() } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddGarmentView()
            }
            .alert("Free limit reached", isPresented: $showLimitAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've reached the \(SubscriptionTier.free.garmentLimit ?? 0)-item limit. Upgrade to Pro in Profile for an unlimited wardrobe.")
            }
            // Reset filter when a category disappears (e.g. last item deleted/archived).
            .onChange(of: availableCategories) {
                if let sel = selectedCategory, !availableCategories.contains(sel) {
                    selectedCategory = nil
                }
            }
        }
    }

    // MARK: - Sub-views

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // "All" pill
                filterPill(label: "All", systemImage: "square.grid.2x2", selected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(availableCategories) { category in
                    filterPill(label: category.displayName, systemImage: category.systemImage, selected: selectedCategory == category) {
                        selectedCategory = selectedCategory == category ? nil : category
                    }
                }
            }
        }
    }

    private func filterPill(label: String, systemImage: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                    in: Capsule()
                )
                .foregroundStyle(selected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Your wardrobe is empty", systemImage: "tshirt")
        } description: {
            Text("Add your clothes to start building outfits.")
        } actions: {
            Button("Add Item") { addTapped() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("No \(selectedCategory?.displayName.lowercased() ?? "items") yet", systemImage: selectedCategory?.systemImage ?? "tshirt")
        } description: {
            Text("Add a \(selectedCategory?.displayName.lowercased() ?? "garment") to see it here.")
        } actions: {
            Button("Add Item") { addTapped() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func addTapped() {
        if container.entitlements.canAddGarment(currentCount: garments.count) {
            showingAdd = true
        } else {
            showLimitAlert = true
        }
    }
}

#Preview {
    WardrobeListView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
