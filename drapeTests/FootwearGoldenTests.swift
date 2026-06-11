//
//  FootwearGoldenTests.swift
//  drapeTests
//
//  Golden scenarios for occasion-specific footwear filtering.
//

import Foundation
import Testing
@testable import drape

@Suite("Footwear occasion filtering")
struct FootwearGoldenTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Sandals are excluded from Sport suggestions")
    func sandalsExcludedFromSport() async {
        let sandal = garment(.footwear, footwearSubcategory: .sandal)
        let wardrobe = [
            garment(.top),
            garment(.bottom),
            sandal,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .sport)
        )

        #expect(suggestions.isEmpty)
        #expect(!suggestionsContain(suggestions, garmentID: sandal.id))
    }

    @Test("Athletic shoes appear in Sport suggestions")
    func athleticShoesIncludedInSport() async {
        let sneaker = garment(.footwear, footwearSubcategory: .athletic)
        let wardrobe = [
            garment(.top),
            garment(.bottom),
            sneaker,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .sport)
        )

        #expect(!suggestions.isEmpty)
        #expect(suggestionsContain(suggestions, garmentID: sneaker.id))
    }

    @Test("Untagged footwear still appears in Sport (conservative — no false positives)")
    func untaggedFootwearPassesSport() async {
        let untagged = garment(.footwear)  // footwearSubcategory == nil
        let wardrobe = [
            garment(.top),
            garment(.bottom),
            untagged,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .sport)
        )

        #expect(!suggestions.isEmpty)
        #expect(suggestionsContain(suggestions, garmentID: untagged.id))
    }

    @Test("Sandals are not excluded from Everyday suggestions")
    func sandalsAllowedForEveryday() async {
        let sandal = garment(.footwear, footwearSubcategory: .sandal)
        let wardrobe = [
            garment(.top),
            garment(.bottom),
            sandal,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday)
        )

        #expect(!suggestions.isEmpty)
        #expect(suggestionsContain(suggestions, garmentID: sandal.id))
    }

    @Test("Loafers are excluded from Sport, allowed for Work")
    func loafersExcludedFromSportNotWork() async {
        let loafer = garment(.footwear, formality: .smartCasual, footwearSubcategory: .loafer)
        let sportWardrobe = [garment(.top), garment(.bottom), loafer]
        let workWardrobe  = [
            garment(.top, formality: .business),
            garment(.bottom, formality: .business),
            loafer,
        ]

        let sportSuggestions = await engine.recommend(
            context(wardrobe: sportWardrobe, occasion: .sport)
        )
        let workSuggestions = await engine.recommend(
            context(wardrobe: workWardrobe, occasion: .work)
        )

        #expect(sportSuggestions.isEmpty)
        #expect(!workSuggestions.isEmpty)
        #expect(suggestionsContain(workSuggestions, garmentID: loafer.id))
    }

    @Test("When wardrobe has both sandal and sneaker, Sport picks the sneaker")
    func sportPicksSneakerOverSandal() async {
        let sandal  = garment(.footwear, footwearSubcategory: .sandal)
        let sneaker = garment(.footwear, footwearSubcategory: .athletic)
        let wardrobe = [
            garment(.top),
            garment(.bottom),
            sandal,
            sneaker,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .sport)
        )

        #expect(!suggestions.isEmpty)
        for suggestion in suggestions {
            #expect(!suggestion.garmentIDs.contains(sandal.id))
            #expect(suggestion.garmentIDs.contains(sneaker.id))
        }
    }
}
