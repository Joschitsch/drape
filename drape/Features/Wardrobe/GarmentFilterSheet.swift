//
//  GarmentFilterSheet.swift
//  drape
//
//  Secondary attribute filter sheet (color, formality, warmth, season, style).
//  Category and Favorites are handled by the chip row in WardrobeListView.
//  Presented with background interaction so the grid stays visible and live
//  behind the sheet while the user picks options.
//

import SwiftUI

struct GarmentFilterSheet: View {
    @Binding var filter: GarmentFilter
    let garments: [Garment]

    @Environment(\.dismiss) private var dismiss

    private var facets: GarmentFacets { GarmentFacets(garments) }

    var body: some View {
        NavigationStack {
            Form {
                if !facets.colors.isEmpty {
                    Section("Color") {
                        FlowLayout(spacing: 6) {
                            ForEach(facets.colors) { tag in
                                SwatchButton(colorTag: tag, isSelected: filter.colors.contains(tag)) {
                                    toggle(tag, in: &filter.colors)
                                }
                            }
                        }
                    }
                }

                if !facets.formalities.isEmpty {
                    Section("Formality") {
                        SelectableChipsRow(items: facets.formalities, title: \.displayName,
                                           selection: $filter.formalities)
                    }
                }

                if !facets.warmths.isEmpty {
                    Section("Warmth") {
                        SelectableChipsRow(items: facets.warmths, title: \.displayName,
                                           selection: $filter.warmths)
                    }
                }

                if !facets.seasons.isEmpty {
                    Section("Season") {
                        SelectableChipsRow(items: facets.seasons, title: \.displayName,
                                           selection: $filter.seasons)
                    }
                }

                if !facets.styles.isEmpty {
                    Section("Style") {
                        FlowLayout(spacing: 8) {
                            ForEach(facets.styles, id: \.self) { style in
                                DrapeChip(label: style, active: filter.styles.contains(style)) {
                                    toggle(style, in: &filter.styles)
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") { filter.clear() }
                        .disabled(!filter.isActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func toggle<T: Hashable>(_ value: T, in set: inout Set<T>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

#Preview {
    @Previewable @State var filter = GarmentFilter()
    GarmentFilterSheet(filter: $filter, garments: [])
}
