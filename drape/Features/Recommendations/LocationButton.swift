//
//  LocationButton.swift
//  drape
//
//  The single, consistent control for the location the Style tab plans against.
//  A pill — pin/airplane glyph, location name, chevron — that reads clearly as a
//  button. Used identically in the idle header and the collapsed (results) header
//  so the "change location" affordance is the same in both places.
//

import SwiftUI

struct LocationButton: View {
    /// The active location name (current city or planned place). nil prompts the
    /// user to set one.
    let name: String?
    /// True when planning for a chosen place rather than the current location —
    /// swaps the pin for a travel glyph and prefixes "Planning ·".
    let isPlanning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isPlanning ? "airplane" : "mappin.and.ellipse")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.inkSoft)
                MonoLabel(label, size: 10, color: Theme.ink)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(Theme.inkFaint)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Theme.surface, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(PressableScale(scale: 0.96))
        .accessibilityLabel(isPlanning ? "Planning location" : "Location")
        .accessibilityValue(name ?? "Not set")
        .accessibilityHint("Change the location your looks are planned for")
    }

    private var label: String {
        guard let name, !name.isEmpty else { return "Set location" }
        return isPlanning ? "Planning · \(name)" : name
    }
}

#Preview {
    VStack(spacing: 16) {
        LocationButton(name: "San Francisco", isPlanning: false, action: {})
        LocationButton(name: "Paris, France", isPlanning: true, action: {})
        LocationButton(name: nil, isPlanning: false, action: {})
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppBackground())
}
