//
//  Theme.swift
//  drape
//
//  Lightweight design tokens and the bridge from domain ColorTag to SwiftUI.
//

import SwiftUI

/// Shared spacing / sizing tokens so components stay visually consistent.
enum Theme {
    static let cornerRadius: CGFloat = 14
    static let tileSpacing: CGFloat = 12
    static let contentPadding: CGFloat = 16
}

extension Color {
    /// Builds a color from a 6-digit RGB hex string (no `#`). Falls back to
    /// clear on malformed input.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self = .clear
            return
        }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

extension ColorTag {
    /// The SwiftUI color for this palette entry. Lives in the DesignSystem layer
    /// so the domain enum stays UI-free.
    var color: Color { Color(hex: hex) }
}
