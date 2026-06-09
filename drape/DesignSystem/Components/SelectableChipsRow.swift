//
//  SelectableChipsRow.swift
//  drape
//
//  The canonical multi-select chip control: a wrapping set of `DrapeChip`s that
//  toggle membership in a `Set`. Wrapping (not horizontal scroll) so nothing is
//  clipped off-screen.
//

import SwiftUI

/// Multi-select control: wrapping chips that toggle membership in a `Set`.
/// Used for seasons, styles and other multi-value fields.
struct SelectableChipsRow<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Set<Item>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                let isOn = selection.contains(item)
                DrapeChip(label: title(item), active: isOn) {
                    if isOn { selection.remove(item) } else { selection.insert(item) }
                }
            }
        }
    }
}
