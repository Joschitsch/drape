//
//  EmptyReasonTests.swift
//  drapeTests
//
//  Pins the empty-state diagnosis: a wardrobe that can't assemble an outfit
//  (missing slots) must read differently from one whose candidates were all
//  rejected by the occasion/weather hard filters.
//

import Foundation
import Testing
@testable import drape

@Suite("Empty result reason")
struct EmptyReasonTests {
    typealias Reason = RecommendationsViewModel.EmptyReason

    // MARK: - Slot coverage

    @Test("Empty wardrobe is missing slots")
    func emptyWardrobe() {
        #expect(RecommendationsViewModel.emptyReason(for: []) == .missingSlots)
    }

    @Test("No footwear is missing slots")
    func noFootwear() {
        let reason = RecommendationsViewModel.emptyReason(for: [garment(.top), garment(.bottom), garment(.dress)])
        #expect(reason == .missingSlots)
    }

    @Test("Footwear without a top+bottom pair or dress is missing slots")
    func footwearOnly() {
        #expect(RecommendationsViewModel.emptyReason(for: [garment(.footwear)]) == .missingSlots)
        #expect(RecommendationsViewModel.emptyReason(for: [garment(.footwear), garment(.top)]) == .missingSlots)
        #expect(RecommendationsViewModel.emptyReason(for: [garment(.footwear), garment(.bottom)]) == .missingSlots)
    }

    @Test("Outerwear and accessories don't count toward coverage")
    func nonCoreCategoriesDontCover() {
        let reason = RecommendationsViewModel.emptyReason(
            for: [garment(.footwear), garment(.outerwear), garment(.accessory)]
        )
        #expect(reason == .missingSlots)
    }

    @Test("Top + bottom + footwear is covered, so emptiness means filtering")
    func topBottomFootwearCovered() {
        let reason = RecommendationsViewModel.emptyReason(
            for: [garment(.top), garment(.bottom), garment(.footwear)]
        )
        #expect(reason == .nothingSuitsContext)
    }

    @Test("Dress + footwear is covered, so emptiness means filtering")
    func dressFootwearCovered() {
        let reason = RecommendationsViewModel.emptyReason(for: [garment(.dress), garment(.footwear)])
        #expect(reason == .nothingSuitsContext)
    }

    // MARK: - Agreement with the engine's hard filters

    @Test("Casual wardrobe + formal occasion: engine empty, reason is filtering")
    func formalityFilterProducesNothingSuits() async {
        let wardrobe = [
            garment(.top, formality: .casual),
            garment(.bottom, formality: .casual),
            garment(.footwear, formality: .casual),
        ]
        let suggestions = await RuleBasedRecommendationEngine().recommend(
            context(wardrobe: wardrobe, occasion: .formal)
        )

        #expect(suggestions.isEmpty)
        #expect(RecommendationsViewModel.emptyReason(for: wardrobe) == .nothingSuitsContext)
    }

    @Test("All-light wardrobe in the cold: engine empty, reason is filtering")
    func warmthFilterProducesNothingSuits() async {
        let wardrobe = [
            garment(.top, warmth: .light),
            garment(.bottom, warmth: .light),
            garment(.footwear, warmth: .light),
        ]
        let suggestions = await RuleBasedRecommendationEngine().recommend(
            context(wardrobe: wardrobe, occasion: .everyday, weather: cold5)
        )

        #expect(suggestions.isEmpty)
        #expect(RecommendationsViewModel.emptyReason(for: wardrobe) == .nothingSuitsContext)
    }
}
