//
//  WarmthLevel.swift
//  drape
//
//  Domain enum: how warm a garment is, for weather-aware suggestions.
//

import Foundation

/// How much warmth a garment provides. Int-backed and ordered so the engine can
/// match total outfit warmth against the current temperature.
enum WarmthLevel: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case light = 0
    case medium = 1
    case warm = 2
    case veryWarm = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .medium: "Medium"
        case .warm: "Warm"
        case .veryWarm: "Very Warm"
        }
    }

    /// Upper temperature (°C) at which this warmth level is comfortable.
    /// `.light` has no upper limit — a t-shirt is always right when it's hot.
    var comfortableUpToCelsius: Double {
        switch self {
        case .light:    .infinity  // t-shirt — no upper limit
        case .medium:   22         // light layers — fine up to 22°C
        case .warm:     16         // jacket — fine up to 16°C
        case .veryWarm: 10         // heavy coat — fine up to 10°C
        }
    }

    /// Lower temperature (°C) at which this warmth level is comfortable.
    /// `.veryWarm` has no lower limit — a heavy coat is always right when it's freezing.
    var comfortableDownToCelsius: Double {
        switch self {
        case .light:    18         // t-shirt feels cold below 18°C
        case .medium:   10         // unchanged
        case .warm:      0         // unchanged
        case .veryWarm: -.infinity // unchanged
        }
    }

    static func < (lhs: WarmthLevel, rhs: WarmthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
