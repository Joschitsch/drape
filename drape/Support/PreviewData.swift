//
//  PreviewData.swift
//  drape
//
//  Sample data for SwiftUI previews and first-launch demo content.
//

import Foundation
import SwiftData

/// Builds and inserts representative sample data. Used by preview containers and
/// to give the app some content on first launch (Step 1); real capture replaces
/// the need for this once the wardrobe has user items.
enum PreviewData {

    /// Sample garments covering the main slots.
    @MainActor
    static func sampleGarments() -> [Garment] {
        [
            Garment(category: .top, primaryColor: .white, formality: .smartCasual,
                    warmth: .light, seasons: [.spring, .summer], styles: [.minimal, .classic],
                    brand: "Everlane"),
            Garment(category: .top, primaryColor: .navy, formality: .casual,
                    warmth: .medium, seasons: [.spring, .autumn], styles: [.classic]),
            Garment(category: .bottom, primaryColor: .blue, formality: .casual,
                    warmth: .medium, seasons: [.spring, .autumn, .winter], styles: [.streetwear],
                    brand: "Levi's"),
            Garment(category: .bottom, primaryColor: .beige, formality: .business,
                    warmth: .medium, seasons: [.spring, .summer], styles: [.classic, .elegant]),
            Garment(category: .footwear, primaryColor: .white, formality: .casual,
                    warmth: .light, seasons: [.spring, .summer], styles: [.minimal, .sporty]),
            Garment(category: .footwear, primaryColor: .brown, formality: .business,
                    warmth: .medium, seasons: [.autumn, .winter], styles: [.classic]),
            Garment(category: .outerwear, primaryColor: .olive, formality: .casual,
                    warmth: .warm, seasons: [.autumn, .winter], styles: [.streetwear]),
            Garment(category: .accessory, primaryColor: .black, formality: .smartCasual,
                    warmth: .light, seasons: Season.allCases, styles: [.minimal]),
        ]
    }

    /// Ensures a (single) `UserProfile` exists. Safe to call on every launch —
    /// used by the running app so there's always a profile to personalise with,
    /// without seeding any fake garments into a real user's wardrobe.
    @MainActor
    static func ensureProfile(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile())
        try? context.save()
    }

    /// Inserts a profile, sample garments and one demo outfit. Used by preview
    /// and test containers only — never the production store.
    @MainActor
    static func seed(into context: ModelContext) {
        let profile = UserProfile(
            preferredStyles: [.minimal, .classic],
            preferredColors: [.navy, .white, .beige],
            defaultFormality: .smartCasual
        )
        context.insert(profile)

        let garments = sampleGarments()
        garments.forEach(context.insert)

        if let top = garments.first(where: { $0.category == .top }),
           let bottom = garments.first(where: { $0.category == .bottom }),
           let shoes = garments.first(where: { $0.category == .footwear }) {
            let outfit = Outfit(
                name: "Easy Weekend",
                garments: [top, bottom, shoes],
                occasion: .everyday,
                tags: ["weekend", "comfortable"]
            )
            context.insert(outfit)
        }

        try? context.save()
    }
}
