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

    // ── Warm neutral palette — adaptive light ("paper") / dark ("ink") ──
    // Every token resolves per the active interface style so the whole app
    // follows the system appearance. Light values are the design's `paper`
    // LOOK; dark values are its `ink` LOOK.
    //
    /// Near-black warm ink (light) / warm off-white (dark) — primary text & fills.
    static let ink     = adaptive(Color(hex: "1C1A17"), Color(hex: "F2EEE6"))
    /// Main screen background.
    static let paper   = adaptive(Color(hex: "F6F4EF"), Color(hex: "171614"))
    /// Card / section fill.
    static let surface = adaptive(Color(hex: "FCFBF8"), Color(hex: "201E1B"))
    /// Raised / selected surfaces.
    static let raised  = adaptive(Color(hex: "FFFFFF"), Color(hex: "27241F"))
    /// Secondary text.
    static let inkSoft = adaptive(Color(hex: "6B655C"), Color(hex: "A39C90"))
    /// Captions, mono labels.
    static let inkFaint = adaptive(Color(hex: "A8A095"), Color(hex: "6E675C"))
    /// Hairline separator (10% ink light / 13% paper dark).
    static let line    = adaptive(Color(hex: "1C1A17").opacity(0.10), Color(hex: "F2EEE6").opacity(0.13))
    /// Softer hairline for inset row separators (6% / 7%).
    static let lineSoft = adaptive(Color(hex: "1C1A17").opacity(0.06), Color(hex: "F2EEE6").opacity(0.07))
    /// Drop-shadow color — subtle in light, deeper in dark where shadows read less.
    static let shadow  = adaptive(Color.black.opacity(0.15), Color.black.opacity(0.45))
    /// Graphite the museum-canvas glyph mixes toward; lightened in dark so the
    /// outline stays visible against the deep canvas wash.
    static let canvasGraphite = adaptive(Color(hex: "4A4A46"), Color(hex: "C9C4BA"))
    /// Neutral base the museum-canvas wash mixes the garment color toward —
    /// white in light, a deep warm graphite in dark so tiles sit in the UI.
    static let canvasBase = adaptive(.white, Color(hex: "2A2722"))

    /// Resolves to `light` or `dark` based on the active `userInterfaceStyle`.
    static func adaptive(_ light: Color, _ dark: Color) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    // ── Editorial type ramp (bundled faces, see DrapeFonts) ──────────────
    // All three helpers scale with Dynamic Type via `relativeTo:` so the app
    // honors the user's text-size setting (clamped at the screen roots so the
    // editorial layout doesn't break). `size` is the size at the default
    // content size and scales proportionally from there.

    /// Maps a point size to the Dynamic Type text style it should scale with.
    private static func textStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 30...:    .largeTitle
        case 24..<30:  .title
        case 20..<24:  .title2
        case 17..<20:  .title3
        case 15..<17:  .body
        case 13..<15:  .subheadline
        case 11..<13:  .footnote
        default:       .caption2
        }
    }

    /// Newsreader serif display — titles, garment names, story lines.
    /// Defaults to the medium (≈500) optical weight the design uses.
    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        Font.custom(italic ? DrapeFonts.Serif.mediumItalic : DrapeFonts.Serif.medium,
                    size: size, relativeTo: textStyle(for: size))
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
        return Font.custom(name, size: size, relativeTo: textStyle(for: size))
    }
    /// Spline Sans Mono — uppercase letter-spaced kickers and captions.
    static func mono(_ size: CGFloat = 11, weight: Font.Weight = .regular) -> Font {
        Font.custom(weight == .regular ? DrapeFonts.Mono.regular : DrapeFonts.Mono.medium,
                    size: size, relativeTo: textStyle(for: size))
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
