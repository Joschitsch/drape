//
//  OutfitListView.swift
//  drape
//
//  Saved outfits. Step 1: browse seeded outfits. Builder lands in Step 3.
//

import SwiftUI
import SwiftData

struct OutfitListView: View {
    @Query(sort: \Outfit.createdAt, order: .reverse)
    private var outfits: [Outfit]

    var body: some View {
        NavigationStack {
            Group {
                if outfits.isEmpty {
                    ContentUnavailableView(
                        "No outfits yet",
                        systemImage: "square.stack.3d.up",
                        description: Text("Combine wardrobe items into outfits.")
                    )
                } else {
                    List(outfits) { outfit in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(outfit.name).font(.headline)
                            HStack {
                                TagChip(outfit.occasion.displayName)
                                Text("\(outfit.garments.count) items")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Outfits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    // Outfit builder arrives in Step 3.
                    Button { } label: { Image(systemName: "plus") }
                        .disabled(true)
                }
            }
        }
    }
}

#Preview {
    OutfitListView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
