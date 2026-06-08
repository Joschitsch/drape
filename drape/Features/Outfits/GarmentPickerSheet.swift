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

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: Theme.tileSpacing)]

    /// Only garments whose category fills this slot.
    private var matching: [Garment] {
        garments.filter { $0.category.slot == slot }
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
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                            ForEach(matching) { garment in
                                Button {
                                    onPick(garment)
                                    dismiss()
                                } label: {
                                    GarmentTile(garment: garment)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(Theme.contentPadding)
                    }
                }
            }
            .navigationTitle("Choose \(slot.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
