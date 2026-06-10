//
//  FormalityDial.swift
//  drape
//
//  Formality is an ordered scale (Casual → Smart Casual → Business → Formal), so
//  it reads best as a dial — the selected level is named above and updates live
//  as you slide between "Laid-back" and "Black-tie".
//

import SwiftUI

struct FormalityDial: View {
    @Binding var formality: Formality

    private var sliderValue: Binding<Double> {
        Binding(
            get: { Double(formality.rawValue) },
            set: { formality = Formality(rawValue: Int($0.rounded())) ?? formality }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SerifText(formality.displayName, size: 18)
            Slider(value: sliderValue, in: 0...Double(Formality.allCases.count - 1), step: 1)
                .tint(Theme.ink)
            HStack {
                MonoLabel("Laid-back", size: 9)
                Spacer()
                MonoLabel("Black-tie", size: 9)
            }
        }
    }
}
