//
//  WeatherGoldenTests.swift
//  drapeTests
//
//  Golden scenarios pinning the warmth hard filter and rain behavior.
//

import Foundation
import Testing
@testable import drape

@Suite("Weather behavior")
struct WeatherGoldenTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Heavy layers are filtered out on a hot day")
    func tooWarmForHotDayIsFiltered() async {
        let wardrobe = [
            garment(.top, warmth: .veryWarm),
            garment(.bottom, warmth: .veryWarm),
            garment(.footwear, warmth: .medium),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, weather: hot28)
        )

        #expect(suggestions.isEmpty)
    }

    @Test("Cold day always picks the warm top over the light one")
    func coldDayPicksWarmLayer() async {
        let lightTop = garment(.top, warmth: .light)
        let warmTop = garment(.top, warmth: .warm)
        let wardrobe = [
            lightTop,
            warmTop,
            garment(.bottom, warmth: .medium),
            garment(.footwear, warmth: .medium),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, weather: cold5)
        )

        #expect(!suggestions.isEmpty)
        for suggestion in suggestions {
            let items = resolve(suggestion, in: wardrobe)
            #expect(items.contains { $0.id == warmTop.id })
            #expect(!items.contains { $0.id == lightTop.id })
        }
    }

    @Test("Rain ranks the outfit with outerwear first")
    func rainPrefersOuterwear() async {
        let coat = garment(.outerwear, warmth: .medium)
        let wardrobe = [
            garment(.top, warmth: .medium),
            garment(.bottom, warmth: .medium),
            garment(.footwear, warmth: .medium),
            coat,
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, weather: rainy15)
        )

        #expect(suggestions.count >= 2) // with and without the coat
        let top = suggestions[0]
        #expect(top.garmentIDs.contains(coat.id))
    }
}
