//
//  OutfitListView.swift
//  drape
//
//  Saved outfits: browse, open detail, and build new ones.
//

import SwiftUI
import SwiftData

struct OutfitListView: View {
    @Query(sort: \Outfit.createdAt, order: .reverse)
    private var outfits: [Outfit]

    @State private var showingBuilder = false

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty {
                    emptyState
                } else {
                    List(outfits) { outfit in
                        NavigationLink(value: outfit) {
                            OutfitRow(outfit: outfit)
                        }
                    }
                }
            }
            .navigationTitle("Outfits")
            .navigationDestination(for: Outfit.self) { OutfitDetailView(outfit: $0) }
            .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingBuilder = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                OutfitBuilderView()
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No outfits yet", systemImage: "square.stack.3d.up")
        } description: {
            Text("Combine wardrobe items into outfits.")
        } actions: {
            Button("New Outfit") { showingBuilder = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

/// A single outfit row: name, occasion, and a strip of garment thumbnails.
private struct OutfitRow: View {
    let outfit: Outfit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(outfit.name).font(.headline)
            HStack(spacing: 8) {
                ForEach(outfit.garments.prefix(5)) { garment in
                    NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category)
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            HStack {
                TagChip(outfit.occasion.displayName)
                if outfit.wearCount > 0 {
                    Text("Worn \(outfit.wearCount)×")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    OutfitListView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
