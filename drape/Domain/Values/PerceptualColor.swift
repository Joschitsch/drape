//
//  PerceptualColor.swift
//  drape
//
//  Domain value type: a garment color expressed in perceptual terms (HSL),
//  parsed once from a hex string. The recommendation engine reasons about color
//  through this type — real hue/saturation/lightness — rather than snapping to a
//  coarse palette family. UI-free, so it lives in the domain layer.
//

import Foundation

/// A color described by its sRGB components and the perceptual quantities the
/// harmony scorers care about. Built from a 6-digit hex string (no leading `#`);
/// malformed input parses as black.
nonisolated struct PerceptualColor: Equatable, Hashable, Sendable {
    /// 0...1 sRGB components.
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    /// Parses a 6-digit RGB hex string (leading `#` and stray punctuation are
    /// tolerated). The single owner of hex→RGB parsing in the domain.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        guard cleaned.count == 6, Scanner(string: cleaned).scanHexInt64(&value) else {
            self.init(red: 0, green: 0, blue: 0)
            return
        }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue:  Double(value & 0xFF) / 255
        )
    }

    /// 6-digit uppercase hex, no leading `#`.
    var hex: String {
        String(format: "%02X%02X%02X",
               Int((red * 255).rounded()),
               Int((green * 255).rounded()),
               Int((blue * 255).rounded()))
    }

    // MARK: - Perceptual quantities

    private var maxComponent: Double { max(red, green, blue) }
    private var minComponent: Double { min(red, green, blue) }

    /// Colorfulness, 0 (grey) … ~1 (vivid). Max-minus-min of the channels.
    var chroma: Double { maxComponent - minComponent }

    /// Perceived brightness, 0 (black) … 1 (white). Rec. 601 luma — kept for
    /// continuity with the light/dark contrast term in color harmony.
    var luminance: Double { 0.299 * red + 0.587 * green + 0.114 * blue }

    /// HSL lightness, 0 (black) … 1 (white).
    var lightness: Double { (maxComponent + minComponent) / 2 }

    /// HSL saturation, 0 (grey) … 1 (pure). Normalises chroma for lightness, so a
    /// dark-but-vivid color still reads saturated.
    var saturation: Double {
        let c = chroma
        guard c > 0 else { return 0 }
        return c / (1 - abs(2 * lightness - 1))
    }

    /// HSL hue in degrees, 0…360. Undefined for greys; returns 0 there, so always
    /// pair a hue read with `isNeutral`.
    var hue: Double {
        let c = chroma
        guard c > 0 else { return 0 }
        let mx = maxComponent
        let h: Double
        if mx == red {
            h = ((green - blue) / c).truncatingRemainder(dividingBy: 6)
        } else if mx == green {
            h = (blue - red) / c + 2
        } else {
            h = (red - green) / c + 4
        }
        let deg = h * 60
        return deg < 0 ? deg + 360 : deg
    }

    /// A color reads as neutral when it carries little color — greys, off-whites,
    /// inks, and the muted earth tones the editorial palette leans on. Neutrals
    /// pair with anything, so the harmony scorer excludes them from hue checks.
    ///
    /// Uses chroma rather than HSL saturation: saturation balloons toward 1 for
    /// near-white and near-black colors (tiny absolute colorfulness over a tiny
    /// denominator), which would wrongly tag an off-white like ivory as an accent.
    /// Threshold calibrated against the color golden tests.
    var isNeutral: Bool { chroma < 0.14 }

    /// Smallest angular distance between two hues, 0…180 degrees.
    func hueDistance(to other: PerceptualColor) -> Double {
        let d = abs(hue - other.hue).truncatingRemainder(dividingBy: 360)
        return min(d, 360 - d)
    }

    /// The relationship between two chromatic colors' hues. Callers should only
    /// consult this for non-neutral colors.
    func hueRelationship(to other: PerceptualColor) -> HueRelationship {
        switch hueDistance(to: other) {
        case ..<40:   return .analogous
        case 150...:  return .complementary
        default:      return .clashing   // the discord zone in between
        }
    }
}

/// How two chromatic hues relate on the color wheel. Drives color-harmony scoring.
nonisolated enum HueRelationship: Sendable {
    /// Hues sit close together — a cohesive, tonal pairing.
    case analogous
    /// Hues sit roughly opposite — deliberate, balanced contrast.
    case complementary
    /// Hues sit in the awkward middle — reads as a clash.
    case clashing
}
