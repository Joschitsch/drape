//
//  OccasionPreferenceStep.swift
//  drape
//
//  Single onboarding step: pick formality + styles for one occasion.
//

import SwiftUI

struct OccasionPreferenceStep: View {
    let occasion: Occasion
    @Binding var formality: Formality
    @Binding var styles: Set<StyleTag>

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(occasion.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 30, alignment: .leading)
                    SerifText(occasion.displayName, size: 24)
                }
                Text("How do you like to dress for \(occasion.displayName.lowercased())?")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Formality")
                SingleChoiceChips(items: Formality.allCases, title: \.displayName, selection: $formality)
            }

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Style vibes · pick any")
                SelectableChipsRow(items: StyleTag.allCases, title: \.displayName, selection: $styles)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.ignoresSafeArea())
    }
}
