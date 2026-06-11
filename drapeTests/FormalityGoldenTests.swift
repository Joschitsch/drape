//
//  FormalityGoldenTests.swift
//  drapeTests
//
//  Golden scenarios for the formality hard floor: no core garment may sit
//  outside the occasion's tolerance band, regardless of how well the rest of
//  the outfit scores on warmth, color, or style.
//

import Foundation
import Testing
@testable import drape

@Suite("Formality hard floor")
struct FormalityGoldenTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Formal occasion at 28°C never includes a casual bottom")
    func shortsNeverWinFormalOnHotDay() async {
        let shorts = garment(.bottom, formality: .casual, warmth: .light)
        let trousers = garment(.bottom, formality: .business, warmth: .light)
        let wardrobe = [
            garment(.top, formality: .formal, warmth: .light),
            shorts,
            trousers,
            garment(.footwear, formality: .formal, warmth: .light),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal, weather: hot28)
        )

        #expect(!suggestions.isEmpty)
        #expect(!suggestionsContain(suggestions, garmentID: shorts.id))
        for suggestion in suggestions {
            for item in coreGarments(resolve(suggestion, in: wardrobe)) {
                #expect(item.formality.rawValue >= Formality.business.rawValue)
            }
        }
    }

    @Test("Averaging cannot dilute a single too-casual item")
    func averagingDilutionRejected() async {
        // Old behavior: avg (3+1+3)/3 = 2.33, distance 0.67 ≤ 1.0 → passed.
        let wardrobe = [
            garment(.top, formality: .formal),
            garment(.bottom, formality: .smartCasual),
            garment(.footwear, formality: .formal),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal)
        )

        #expect(suggestions.isEmpty)
    }

    @Test("A user occasion preference does not widen the formal tolerance")
    func userPreferenceKeepsOccasionTolerance() async {
        let casualish = garment(.bottom, formality: .smartCasual)
        let dressy = garment(.bottom, formality: .formal)
        let wardrobe = [
            garment(.top, formality: .formal),
            casualish,
            dressy,
            garment(.footwear, formality: .formal),
        ]
        let profile = ProfilePreferences(occasionPreferences: [
            OccasionPreference(occasion: .formal, targetFormality: .formal, styles: [])
        ])

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal, profile: profile)
        )

        #expect(!suggestions.isEmpty)
        #expect(!suggestionsContain(suggestions, garmentID: casualish.id))
    }

    @Test("A user preference moves the target, not the tolerance")
    func userPreferenceMovesTarget() async {
        // Work tolerance is 1.5; pref target smartCasual(1) admits casual(0),
        // smartCasual(1), business(2) but excludes formal(3).
        let casual = garment(.bottom, formality: .casual)
        let formal = garment(.bottom, formality: .formal)
        let wardrobe = [
            garment(.top, formality: .smartCasual),
            casual,
            garment(.bottom, formality: .business),
            formal,
            garment(.footwear, formality: .smartCasual),
        ]
        let profile = ProfilePreferences(occasionPreferences: [
            OccasionPreference(occasion: .work, targetFormality: .smartCasual, styles: [])
        ])

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .work, profile: profile)
        )

        #expect(suggestionsContain(suggestions, garmentID: casual.id))
        #expect(!suggestionsContain(suggestions, garmentID: formal.id))
    }

    @Test("Outerwear and accessories are exempt from the floor")
    func outerwearExemptFromFloor() async {
        let parka = garment(.outerwear, formality: .casual, warmth: .veryWarm)
        let wardrobe = [
            garment(.top, formality: .formal, warmth: .warm),
            garment(.bottom, formality: .formal, warmth: .medium),
            garment(.footwear, formality: .formal, warmth: .medium),
            parka,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal, weather: cold5)
        )

        #expect(suggestionsContain(suggestions, garmentID: parka.id))
    }

    @Test("All-casual wardrobe yields no formal suggestions")
    func allCasualWardrobeYieldsNothingForFormal() async {
        let wardrobe = [
            garment(.top, formality: .casual),
            garment(.bottom, formality: .casual),
            garment(.footwear, formality: .casual),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal)
        )

        #expect(suggestions.isEmpty)
    }

    @Test("Relaxed occasions accept the whole formality range")
    func everydayAcceptsEverything() async {
        let casual = garment(.bottom, formality: .casual)
        let wardrobe = [
            garment(.top, formality: .formal),
            casual,
            garment(.footwear, formality: .smartCasual),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday)
        )

        #expect(!suggestions.isEmpty)
        #expect(suggestionsContain(suggestions, garmentID: casual.id))
    }

    @Test("Without weather the formality floor still applies")
    func noWeatherStillEnforcesFloor() async {
        let shorts = garment(.bottom, formality: .casual)
        let wardrobe = [
            garment(.top, formality: .formal),
            shorts,
            garment(.bottom, formality: .business),
            garment(.footwear, formality: .formal),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .formal, weather: nil)
        )

        #expect(!suggestions.isEmpty)
        #expect(!suggestionsContain(suggestions, garmentID: shorts.id))
    }
}
