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

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    emptyState
                } else {
                    grid
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
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                ForEach(garments) { garment in
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
