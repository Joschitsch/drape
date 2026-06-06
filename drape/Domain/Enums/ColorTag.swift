//
//  ColorTag.swift
//  drape
//
//  Domain enum: a normalized palette of garment colors.
//

import Foundation

/// A constrained palette of garment colors. Keeping colors as a fixed set
/// (rather than free RGB) makes color-harmony scoring tractable and the UI
/// consistent. The hex swatch lives here; the SwiftUI `Color` is built in the
/// DesignSystem layer so the domain stays UI-free.
enum ColorTag: String, Codable, CaseIterable, Identifiable, Sendable {
    // Muted editorial fashion palette (matches the design's named swatches).
    case ecru, ivory, oat, camel, tobacco, chocolate
    case charcoal, ink, sage, forest, denim, navy
    case rust, burgundy, mauve, slate

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Hex used to render the swatch (no leading `#`).
    var hex: String {
        switch self {
        case .ecru: "E4DCC9"
        case .ivory: "F0EADB"
        case .oat: "D8CDB6"
        case .camel: "BD9A6E"
        case .tobacco: "8A6A4A"
        case .chocolate: "5B463A"
        case .charcoal: "3A3833"
        case .ink: "23211D"
        case .sage: "9AA487"
        case .forest: "3F4A3C"
        case .denim: "6C82A0"
        case .navy: "2C3A4F"
        case .rust: "A8563B"
        case .burgundy: "6B2F36"
        case .mauve: "9C8189"
        case .slate: "6A6E72"
        }
    }

    /// Coarse family used for harmony heuristics. Neutrals pair with anything.
    var family: ColorFamily {
        switch self {
        case .ecru, .ivory, .oat, .charcoal, .ink, .slate: .neutral
        case .camel, .tobacco, .chocolate, .rust, .burgundy: .warm
        case .sage, .forest, .denim, .navy, .mauve: .cool
        }
    }

    /// 0...1 sRGB components parsed from `hex`. Used by the heuristic classifier
    /// to match an averaged photo color to the nearest palette entry.
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return (
            Double((value >> 16) & 0xFF) / 255,
            Double((value >> 8) & 0xFF) / 255,
            Double(value & 0xFF) / 255
        )
    }

    /// The palette entry closest to the given sRGB color (Euclidean distance).
    static func nearest(red: Double, green: Double, blue: Double) -> ColorTag {
        allCases.min { lhs, rhs in
            squaredDistance(lhs, red, green, blue) < squaredDistance(rhs, red, green, blue)
        } ?? .ink
    }

    private static func squaredDistance(_ tag: ColorTag, _ r: Double, _ g: Double, _ b: Double) -> Double {
        let c = tag.rgbComponents
        let dr = c.red - r, dg = c.green - g, db = c.blue - b
        return dr * dr + dg * dg + db * db
    }
}

/// Broad color groupings for the harmony scorer.
enum ColorFamily: String, Codable, Sendable {
    case neutral
    case warm
    case cool
}
