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
    @Binding var styles: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(occasion.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.ink)
                    .frame(width: 30, alignment: .leading)
                SerifText(occasion.displayName, size: 24)
            }

            OccasionPreferenceEditor(
                occasion: occasion,
                formality: $formality,
                styles: $styles
            )

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.ignoresSafeArea())
    }
}
