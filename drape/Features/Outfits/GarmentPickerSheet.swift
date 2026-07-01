//
//  GarmentPickerSheet.swift
//  drape
//
//  Picks a wardrobe garment for a given outfit slot.
//

import SwiftUI
import SwiftData

struct GarmentPickerSheet: View {
    let slot: OutfitSlot
    let onPick: (Garment) -> Void

    @Query(filter: #Predicate<Garment> { !$0.isArchived }, sort: \Garment.createdAt, order: .reverse)
    private var garments: [Garment]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    /// Only garments whose category fills this slot.
    private var matching: [Garment] {
        garments.filter { $0.category.slot == slot }
    }

    /// `matching`, narrowed by the search field (name + brand).
    private var results: [Garment] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return matching }
        return matching.filter {
            $0.displayName.lowercased().contains(q) || ($0.brand?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if matching.isEmpty {
                    ContentUnavailableView(
                        "No \(slot.displayName.lowercased()) items",
                        image: slot.iconName,
                        description: Text("Add \(slot.displayName.lowercased()) pieces to your wardrobe first.")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                            ForEach(results) { garment in
                                Button {
                                    onPick(garment)
                                    dismiss()
                                } label: {
                                    GarmentTile(garment: garment)
                                }
                                .buttonStyle(PressableScale(scale: 0.94))
                            }
                        }
                        .padding(Theme.contentPadding)
                    }
                }
            }
            .navigationTitle("Choose \(slot.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "Search \(slot.displayName.lowercased())")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
