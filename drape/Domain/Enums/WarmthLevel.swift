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

    /// Rough upper temperature (°C) at which this warmth is comfortable on its
    /// own. Used as a heuristic in weather scoring; tuned later with feedback.
    var comfortableUpToCelsius: Double {
        switch self {
        case .light: 30
        case .medium: 20
        case .warm: 12
        case .veryWarm: 5
        }
    }

    static func < (lhs: WarmthLevel, rhs: WarmthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
