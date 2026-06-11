//
//  RecommendationContext.swift
//  drape
//
//  Domain value type: everything the recommendation engine needs as input.
//

import Foundation

/// The complete, self-contained input to a `RecommendationEngine`. Bundling it
/// into one value keeps the engine protocol simple and makes it trivial to test
/// with fixed inputs.
struct RecommendationContext: Sendable {
    /// Candidate garments to build outfits from (already filtered to non-archived).
    var wardrobe: [GarmentSnapshot]
    var occasion: Occasion
    var weather: WeatherSnapshot?
    var profile: ProfilePreferences
    /// Recently worn garment ids → most recent wear date, for recency penalties.
    var recentWears: [UUID: Date]
    /// How many outfit suggestions to return.
    var desiredCount: Int

    init(
        wardrobe: [GarmentSnapshot],
        occasion: Occasion,
        weather: WeatherSnapshot? = nil,
        profile: ProfilePreferences = .init(),
        recentWears: [UUID: Date] = [:],
        desiredCount: Int = 5
    ) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.weather = weather
        self.profile = profile
        self.recentWears = recentWears
        self.desiredCount = desiredCount
    }
}

/// An immutable, `Sendable` snapshot of a `Garment`'s recommendation-relevant
/// fields. Decouples the engine from SwiftData reference types so it can run off
/// the main actor and be unit-tested without a `ModelContext`.
struct GarmentSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var category: GarmentCategory
    var primaryColor: ColorTag
    var secondaryColors: [ColorTag]
    var formality: Formality
    var warmth: WarmthLevel
    var seasons: [Season]
    var styles: [String]
}

/// The subset of `UserProfile` the engine reads.
struct ProfilePreferences: Sendable {
    var preferredStyles: [String]
    var occasionPreferences: [OccasionPreference]

    init(
        preferredStyles: [String] = [],
        occasionPreferences: [OccasionPreference] = []
    ) {
        self.preferredStyles = preferredStyles
        self.occasionPreferences = occasionPreferences
    }

    func occasionPreference(for occasion: Occasion) -> OccasionPreference? {
        occasionPreferences.first { $0.occasion == occasion }
    }
}

extension Garment {
    /// Projects this model into a `Sendable` snapshot for the engine.
    var snapshot: GarmentSnapshot {
        GarmentSnapshot(
            id: id,
            category: category,
            primaryColor: primaryColor,
            secondaryColors: secondaryColors,
            formality: formality,
            warmth: warmth,
            seasons: seasons,
            styles: styles
        )
    }
}
