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

    // ── Warm neutral palette (matches the design's paper/ink system) ──
    /// Near-black warm ink — primary text and solid fills.
    static let ink     = Color(hex: "1C1A17")
    /// Warm off-white — main screen background.
    static let paper   = Color(hex: "F6F4EF")
    /// Slightly lighter — card and section fill.
    static let surface = Color(hex: "FCFBF8")
    /// Pure white — raised/selected surfaces.
    static let raised  = Color(hex: "FFFFFF")
    /// Medium warm gray — secondary text.
    static let inkSoft = Color(hex: "6B655C")
    /// Light warm gray — captions, mono labels.
    static let inkFaint = Color(hex: "A8A095")
    /// Hairline separator (10% of ink).
    static let line    = Color(red: 28/255, green: 26/255, blue: 23/255).opacity(0.10)
    /// Softer hairline for inset row separators (6% of ink).
    static let lineSoft = Color(red: 28/255, green: 26/255, blue: 23/255).opacity(0.06)

    // ── Editorial type ramp (bundled faces, see DrapeFonts) ──────────────
    /// Newsreader serif display — titles, garment names, story lines.
    /// Defaults to the medium (≈500) optical weight the design uses.
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        Font.custom(italic ? DrapeFonts.Serif.mediumItalic : DrapeFonts.Serif.medium, size: size)
    }
    /// Hanken Grotesk — body copy, nav titles, rows.
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let name: String
        switch weight {
        case .bold, .heavy, .black:       name = DrapeFonts.Body.bold
        case .semibold:                   name = DrapeFonts.Body.semibold
        case .medium:                     name = DrapeFonts.Body.medium
        default:                          name = DrapeFonts.Body.regular
        }
        return Font.custom(name, size: size)
    }
    /// Spline Sans Mono — uppercase letter-spaced kickers and captions.
    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        Font.custom(weight == .regular ? DrapeFonts.Mono.regular : DrapeFonts.Mono.medium, size: size)
    }
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
