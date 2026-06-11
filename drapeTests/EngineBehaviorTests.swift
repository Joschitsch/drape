//
//  EngineBehaviorTests.swift
//  drapeTests
//
//  Golden scenarios pinning general engine behavior: recency variety,
//  degenerate wardrobes, result count, ordering, and determinism.
//

import Foundation
import Testing
@testable import drape

@Suite("Engine behavior")
struct EngineBehaviorTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("A garment worn yesterday loses to an identical fresh one")
    func recencyEncouragesVariety() async {
        let wornTop = garment(.top)
        let freshTop = garment(.top)
        let wardrobe = [
            wornTop,
            freshTop,
            garment(.bottom),
            garment(.footwear),
        ]
        let yesterday = Date.now.addingTimeInterval(-86_400)

        let suggestions = await engine.recommend(
            context(
                wardrobe: wardrobe,
                occasion: .everyday,
                recentWears: [wornTop.id: yesterday]
            )
        )

        #expect(suggestions.count == 2)
        #expect(suggestions[0].garmentIDs.contains(freshTop.id))
    }

    @Test("Degenerate wardrobes produce no suggestions")
    func degenerateWardrobes() async {
        let empty = await engine.recommend(
            context(wardrobe: [], occasion: .everyday)
        )
        #expect(empty.isEmpty)

        let noFootwear = await engine.recommend(
            context(wardrobe: [garment(.top), garment(.bottom)], occasion: .everyday)
        )
        #expect(noFootwear.isEmpty)

        let dressNoShoes = await engine.recommend(
            context(wardrobe: [garment(.dress)], occasion: .everyday)
        )
        #expect(dressNoShoes.isEmpty)
    }

    @Test("Respects desiredCount and returns sorted scores in 0...1")
    func desiredCountAndOrdering() async {
        let wardrobe = [
            garment(.top), garment(.top), garment(.top),
            garment(.bottom),
            garment(.footwear),
        ]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 2)
        )

        #expect(suggestions.count == 2)
        for suggestion in suggestions {
            #expect(suggestion.score >= 0 && suggestion.score <= 1)
        }
        #expect(suggestions[0].score >= suggestions[1].score)
    }

    @Test("Same context twice gives identical results below the shuffle cap")
    func deterministicBelowShuffleThreshold() async {
        let wardrobe = [
            garment(.top, formality: .smartCasual, color: .navy, styles: ["minimal"]),
            garment(.top, formality: .casual, color: .rust),
            garment(.bottom, formality: .casual, warmth: .medium, color: .denim),
            garment(.footwear, formality: .smartCasual, color: .ivory),
            garment(.outerwear, formality: .smartCasual, warmth: .medium, color: .camel),
        ]
        let ctx = context(wardrobe: wardrobe, occasion: .everyday, weather: rainy15)

        let first = await engine.recommend(ctx)
        let second = await engine.recommend(ctx)

        #expect(first.map(\.garmentIDs) == second.map(\.garmentIDs))
        #expect(first.map(\.score) == second.map(\.score))
    }
}
