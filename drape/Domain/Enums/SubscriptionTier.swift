//
//  SubscriptionTier.swift
//  drape
//
//  Domain enum: freemium entitlement level.
//

import Foundation

/// The user's entitlement level. The free tier caps wardrobe size and advanced
/// AI features; pro unlocks them. Real purchasing is wired later behind
/// `EntitlementService` — this enum is the swappable source of truth.
enum SubscriptionTier: String, Codable, CaseIterable, Identifiable, Sendable {
    case free
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        }
    }

    /// Maximum number of garments allowed. `nil` means unlimited.
    var garmentLimit: Int? {
        switch self {
        case .free: 30
        case .pro: nil
        }
    }
}

/// Features that can be gated behind a tier. Checked via `EntitlementService`.
enum ProFeature: String, Codable, CaseIterable, Sendable {
    case weeklyOutfitPlan
    case capsuleSuggestions
    case wardrobeAnalytics
    case advancedRecommendations
}
