//
//  StyleTuning.swift
//  drape
//
//  Per-user personalisation for the recommendation engine: a few onboarding
//  appetites plus bounded, feedback-driven weight nudges. Deliberately *not* a
//  learned model — every value is human-readable and clamped, so the engine
//  stays explainable and the personalisation can't drift into nonsense.
//

import Foundation

/// How much color a user wants in a look.
enum ColorAppetite: String, Codable, CaseIterable, Identifiable, Sendable {
    case neutrals, balanced, colorful
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .neutrals: "Mostly neutrals"
        case .balanced: "A bit of both"
        case .colorful: "I love color"
        }
    }
}

/// Appetite for prints and pattern mixing.
enum PatternTolerance: String, Codable, CaseIterable, Identifiable, Sendable {
    case avoid, sometimes, love
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .avoid:     "Avoid patterns"
        case .sometimes: "Sometimes"
        case .love:      "Love them"
        }
    }
}

/// Preferred overall silhouette.
enum SilhouettePreference: String, Codable, CaseIterable, Identifiable, Sendable {
    case fitted, balanced, relaxed
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fitted:   "Fitted"
        case .balanced: "Balanced"
        case .relaxed:  "Relaxed"
        }
    }
}

/// A reason the user gives when rating a suggestion. Each maps to a bounded nudge
/// of the relevant scorer weight or bias.
enum FeedbackReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case tooColorful, tooPlain, notMySilhouette, tooDressy
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .tooColorful:     "Too colorful"
        case .tooPlain:        "Too plain"
        case .notMySilhouette: "Not my silhouette"
        case .tooDressy:       "Too dressy"
        }
    }
}

/// The tunable knobs the engine reads. Onboarding seeds the appetites; thumbs
/// feedback nudges `weightAdjust` and `formalityBias` within hard clamps.
/// `nonisolated` so SwiftData's persisted-property accessor can use the Codable
/// conformance off the main actor (this type is stored directly on `UserProfile`).
nonisolated struct StyleTuning: Codable, Sendable, Equatable {
    var colorAppetite: ColorAppetite = .balanced
    var patternTolerance: PatternTolerance = .sometimes
    var silhouette: SilhouettePreference = .balanced

    /// Per-axis multipliers on the style scorer weights (axis name → factor).
    /// Empty by default (every axis at 1.0); feedback grows it, always clamped.
    var weightAdjust: [String: Double] = [:]
    /// Shifts the effective formality target down/up a touch, e.g. when the user
    /// keeps saying "too dressy". Clamped to ±1 formality level.
    var formalityBias: Double = 0

    static let clampLow = 0.5
    static let clampHigh = 1.8

    /// Effective multiplier for a style axis, including the onboarding appetite.
    func multiplier(for axis: StyleAxis) -> Double {
        var m = weightAdjust[axis.rawValue] ?? 1.0
        switch axis {
        case .color, .focal:
            switch colorAppetite {
            case .neutrals: m *= 1.3   // hold the line on quiet, harmonious looks
            case .balanced: break
            case .colorful: m *= 0.7   // let louder combinations through
            }
        case .pattern:
            switch patternTolerance {
            case .avoid:     m *= 1.3
            case .sometimes: break
            case .love:      m *= 0.7
            }
        case .volume, .structure, .texture, .archetype:
            break
        }
        return min(StyleTuning.clampHigh, max(StyleTuning.clampLow, m))
    }

    var prefersRelaxedSilhouette: Bool { silhouette == .relaxed }

    /// Applies a thumbs rating + reasons, nudging the relevant knobs within clamps.
    /// Positive ratings gently relax pressure on the cited axis; negative ratings
    /// tighten it. No reasons → no change (a bare thumb isn't specific enough).
    mutating func apply(reasons: [FeedbackReason], positive: Bool) {
        let step = positive ? 0.9 : 1.15   // down-rating tightens, up-rating loosens
        for reason in reasons {
            switch reason {
            case .tooColorful:
                nudge(.color, by: step); nudge(.focal, by: step)
            case .tooPlain:
                // "Too plain" is the inverse: loosen color/focal pressure.
                nudge(.color, by: 1 / step); nudge(.focal, by: 1 / step)
            case .notMySilhouette:
                nudge(.volume, by: step); nudge(.structure, by: step)
            case .tooDressy:
                formalityBias = max(-1, min(1, formalityBias - (positive ? -0.2 : 0.3)))
            }
        }
    }

    private mutating func nudge(_ axis: StyleAxis, by factor: Double) {
        let current = weightAdjust[axis.rawValue] ?? 1.0
        weightAdjust[axis.rawValue] = min(StyleTuning.clampHigh,
                                          max(StyleTuning.clampLow, current * factor))
    }
}

/// The style scorer axes that personalisation can scale.
enum StyleAxis: String, Sendable {
    case color, pattern, volume, structure, texture, archetype, focal
}
