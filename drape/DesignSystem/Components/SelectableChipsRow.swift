//
//  SelectableChipsRow.swift
//  drape
//
//  A horizontally scrolling row of toggleable chips for multi-select fields.
//

import SwiftUI

/// Multi-select control: a scrolling row of chips that toggle membership in a
/// `Set`. Used for seasons and styles in the garment form.
struct SelectableChipsRow<Item: Hashable & Identifiable>: View {
    let items: [Item]
    let title: (Item) -> String
    @Binding var selection: Set<Item>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let isOn = selection.contains(item)
                    Button {
                        if isOn { selection.remove(item) } else { selection.insert(item) }
                    } label: {
                        Text(title(item))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                isOn ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                                in: Capsule()
                            )
                            .foregroundStyle(isOn ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
