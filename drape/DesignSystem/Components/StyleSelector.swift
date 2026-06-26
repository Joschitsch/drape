//
//  StyleSelector.swift
//  drape
//
//  Multi-select style picker over the fixed style vocabulary (`Archetype`). One
//  curated set is both what the user picks and what the engine reasons about, so
//  there's no separate "archetype" concept and no free-form custom styles.
//  Selection holds canonical raw values.
//

import SwiftUI

struct StyleSelector: View {
    @Binding var selection: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Archetype.allCases) { style in
                let isOn = selection.contains(style.rawValue)
                DrapeChip(label: style.displayName, active: isOn) {
                    if isOn { selection.remove(style.rawValue) } else { selection.insert(style.rawValue) }
                }
            }
        }
    }
}
