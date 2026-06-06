//
//  UserProfile.swift
//  drape
//
//  SwiftData model: the single user's style preferences and home location.
//

import Foundation
import SwiftData

/// The user's preferences. A single instance is seeded on first launch and
/// edited from the Profile tab. Drives personalisation in the recommendation
/// engine. Subscription tier is intentionally *not* stored here — it lives
/// behind `EntitlementService` so the source can change (mock → StoreKit).
@Model
final class UserProfile {
    var id: UUID = UUID()
    var createdAt: Date = Date.now

    var preferredStyles: [StyleTag] = []
    var preferredColors: [ColorTag] = []
    var defaultFormality: Formality = Formality.smartCasual

    /// Per-occasion formality + style overrides set during onboarding or Profile editing.
    var occasionPreferences: [OccasionPreference] = []
    var hasCompletedOnboarding: Bool = false

    /// Home coordinates for weather lookups when live location is unavailable.
    var homeLatitude: Double?
    var homeLongitude: Double?

    init(
        id: UUID = UUID(),
        preferredStyles: [StyleTag] = [],
        preferredColors: [ColorTag] = [],
        defaultFormality: Formality = .smartCasual,
        occasionPreferences: [OccasionPreference] = [],
        hasCompletedOnboarding: Bool = false
    ) {
        self.id = id
        self.createdAt = .now
        self.preferredStyles = preferredStyles
        self.preferredColors = preferredColors
        self.defaultFormality = defaultFormality
        self.occasionPreferences = occasionPreferences
        self.hasCompletedOnboarding = hasCompletedOnboarding
    }

    func preference(for occasion: Occasion) -> OccasionPreference? {
        occasionPreferences.first { $0.occasion == occasion }
    }
}
