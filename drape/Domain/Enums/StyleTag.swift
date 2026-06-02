//
//  StyleTag.swift
//  drape
//
//  Domain enum: aesthetic styles for user preference and garment vibe.
//

import Foundation

/// Aesthetic style. Used both as a user preference (in `UserProfile`) and,
/// optionally, as a descriptor on garments so the engine can favour items that
/// match the user's taste.
enum StyleTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case minimal
    case classic
    case streetwear
    case sporty
    case bohemian
    case elegant

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .minimal: "Minimal"
        case .classic: "Classic"
        case .streetwear: "Streetwear"
        case .sporty: "Sporty"
        case .bohemian: "Bohemian"
        case .elegant: "Elegant"
        }
    }
}
