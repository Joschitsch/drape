//
//  StyleAttributes.swift
//  drape
//
//  Silhouette, fabric and pattern axes that let the engine reason about *how*
//  a piece is shaped and surfaced, not just what it is. All are String-backed so
//  they persist stably and need no SwiftData migration when cases are added, and
//  all are optional on the garment — "unknown" is a first-class state the engine
//  treats as neutral, never as a penalty.
//

import Foundation

/// How close to the body a garment sits.
enum Fit: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case slim
    case regular
    case relaxed
    case oversized

    var displayName: String {
        switch self {
        case .slim:      "Slim"
        case .regular:   "Regular"
        case .relaxed:   "Relaxed"
        case .oversized: "Oversized"
        }
    }
}

/// Hem position of a top or dress relative to the body.
enum TopLength: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case cropped
    case regular
    case long

    var displayName: String {
        switch self {
        case .cropped: "Cropped"
        case .regular: "Regular"
        case .long:    "Long"
        }
    }
}

/// Leg volume of a bottom.
enum BottomVolume: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case slim
    case straight
    case wide

    var displayName: String {
        switch self {
        case .slim:     "Slim"
        case .straight: "Straight"
        case .wide:     "Wide"
        }
    }
}

/// How much shape a garment holds on its own — drives the "at least one
/// structured element" rule for non-sport looks.
enum Structure: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case soft
    case semiStructured
    case structured

    var displayName: String {
        switch self {
        case .soft:           "Soft"
        case .semiStructured: "Semi-structured"
        case .structured:     "Structured"
        }
    }

    /// True for pieces that lend an outfit a tailored anchor.
    var isStructured: Bool { self != .soft }
}

/// Visual/fabric heft, distinct from `WarmthLevel` (insulation). A linen shirt is
/// light but a chunky knit is heavy; both can read as "warm" or not independently.
enum FabricWeight: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case light
    case medium
    case heavy

    var displayName: String {
        switch self {
        case .light:  "Light"
        case .medium: "Medium"
        case .heavy:  "Heavy"
        }
    }
}

/// Kind of surface pattern. Heuristics in Phase 1 mostly distinguish `solid` from
/// "patterned"; the specific kind is refined later (or set by the user).
enum PatternType: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case solid
    case stripe
    case check
    case floral
    case abstract
    case graphic

    var displayName: String {
        switch self {
        case .solid:    "Solid"
        case .stripe:   "Stripe"
        case .check:    "Check"
        case .floral:   "Floral"
        case .abstract: "Abstract"
        case .graphic:  "Graphic"
        }
    }
}

/// Coarse scale of any pattern. `none` means a solid surface.
enum PatternScale: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case none
    case small
    case medium
    case large

    var displayName: String {
        switch self {
        case .none:   "Solid"
        case .small:  "Small"
        case .medium: "Medium"
        case .large:  "Large"
        }
    }
}
