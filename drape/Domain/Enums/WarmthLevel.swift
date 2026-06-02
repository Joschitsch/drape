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
        case .light:    .infinity
        case .medium:   20
        case .warm:     12
        case .veryWarm:  5
        }
    }

    /// Lower temperature (°C) at which this warmth level is comfortable.
    /// `.veryWarm` has no lower limit — a heavy coat is always right when it's freezing.
    var comfortableDownToCelsius: Double {
        switch self {
        case .light:    20
        case .medium:   10
        case .warm:      0
        case .veryWarm: -.infinity
        }
    }

    static func < (lhs: WarmthLevel, rhs: WarmthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
