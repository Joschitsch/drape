//
//  SingleChoiceChips.swift
//  drape
//
//  The canonical single-select control: a wrapping set of `DrapeChip`s where
//  exactly one is active. The single-select twin of `SelectableChipsRow`, so
//  every enum choice in the app (category, formality, warmth, occasion) reads
//  the same way.
//

import SwiftUI

struct SingleChoiceChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                DrapeChip(label: title(item), active: item == selection) {
                    selection = item
                }
            }
        }
    }
}

/// Optional-selection variant: tapping the active chip deselects to nil.
struct OptionalSingleChoiceChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Item?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                DrapeChip(label: title(item), active: item == selection) {
                    selection = (item == selection) ? nil : item
                }
            }
        }
    }
}
