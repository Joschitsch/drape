//
//  OccasionPreferenceEditor.swift
//  drape
//
//  The conversational editor for one occasion's preferences — a plain-language
//  prompt over a formality dial, and a second prompt over the style selector.
//  Shared by the Profile disclosure and the onboarding step so they match.
//

import SwiftUI

struct OccasionPreferenceEditor: View {
    let occasion: Occasion
    @Binding var formality: Formality
    @Binding var styles: Set<String>
    var customStyles: [String] = []
    var onAddStyle: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                prompt("How dressed up for \(occasion.preferencePhrase)?")
                FormalityDial(formality: $formality)
            }
            VStack(alignment: .leading, spacing: 10) {
                prompt("What's the vibe? Pick any.")
                StyleSelector(selection: $styles, customStyles: customStyles, onAdd: onAddStyle)
            }
        }
    }

    private func prompt(_ text: String) -> some View {
        Text(text)
            .font(Theme.body(15))
            .foregroundStyle(Theme.inkSoft)
    }
}
