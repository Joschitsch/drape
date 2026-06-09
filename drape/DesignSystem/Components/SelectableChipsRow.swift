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

/// Multi-select color control: a wrapping grid of `SwatchButton`s that toggle
/// membership in a `Set<ColorTag>` — the color counterpart to `SelectableChipsRow`.
struct SelectableSwatchRow: View {
    let colors: [ColorTag]
    @Binding var selection: Set<ColorTag>

    init(colors: [ColorTag] = ColorTag.allCases, selection: Binding<Set<ColorTag>>) {
        self.colors = colors
        self._selection = selection
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(colors) { tag in
                let isOn = selection.contains(tag)
                SwatchButton(colorTag: tag, isSelected: isOn) {
                    if isOn { selection.remove(tag) } else { selection.insert(tag) }
                }
            }
        }
    }
}
