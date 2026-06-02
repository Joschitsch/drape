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
    case black, white, gray, beige, brown
    case navy, blue, teal, green, olive
    case yellow, orange, red, pink, purple

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }

    /// Hex used to render the swatch (no leading `#`).
    var hex: String {
        switch self {
        case .black: "1C1C1E"
        case .white: "F5F5F7"
        case .gray: "8E8E93"
        case .beige: "D9C7A8"
        case .brown: "8B5E3C"
        case .navy: "1F2A44"
        case .blue: "3478F6"
        case .teal: "30B0C7"
        case .green: "34A853"
        case .olive: "6B7339"
        case .yellow: "F2C200"
        case .orange: "F5803E"
        case .red: "E5484D"
        case .pink: "F06595"
        case .purple: "8E59D6"
        }
    }

    /// Coarse family used for harmony heuristics. Neutrals pair with anything.
    var family: ColorFamily {
        switch self {
        case .black, .white, .gray, .beige, .brown: .neutral
        case .red, .orange, .yellow, .pink: .warm
        case .navy, .blue, .teal, .green, .olive, .purple: .cool
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
        } ?? .black
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
