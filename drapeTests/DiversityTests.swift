//
//  DiversityTests.swift
//  drapeTests
//
//  Phase 2: the returned set is chosen by Maximal Marginal Relevance, so the
//  surfaced cards differ by more than a single swapped slot instead of being
//  near-duplicate top-N-by-score.
//

import Foundation
import Testing
@testable import drape

@Suite("Result diversity")
struct DiversityTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Top suggestions aren't near-duplicates when alternatives exist")
    func topSuggestionsAreDistinct() async {
        // One top + bottom with many interchangeable shoes would, under pure
        // score ranking, fill every card with the same top+bottom. A second
        // distinct top+bottom pair gives MMR something genuinely different to
        // surface.
        let topA = garment(.top, color: .navy)
        let bottomA = garment(.bottom, color: .charcoal)
        let topB = garment(.top, color: .rust)
        let bottomB = garment(.bottom, color: .oat)
        let shoes = (0..<5).map { _ in garment(.footwear, color: .ivory) }
        let wardrobe = [topA, bottomA, topB, bottomB] + shoes

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 3))

        #expect(suggestions.count >= 2)

        // No two of the surfaced outfits should share the same top *and* bottom.
        func coreKey(_ s: OutfitSuggestion) -> Set<UUID> {
            let core = coreGarments(resolve(s, in: wardrobe))
            return Set(core.map(\.id))
        }
        let keys = suggestions.map(coreKey)
        for i in keys.indices {
            for j in (i + 1)..<keys.count {
                #expect(keys[i] != keys[j], "Surfaced outfits \(i) and \(j) share the same top+bottom")
            }
        }

        // Both distinct pairs should appear across the surfaced set.
        let surfacedIDs = Set(suggestions.flatMap(\.garmentIDs))
        #expect(surfacedIDs.contains(topA.id) && surfacedIDs.contains(topB.id))
    }

    @Test("Lead card is still the highest-scored outfit")
    func leadIsRelevanceAnchor() async {
        let wardrobe = [
            garment(.top), garment(.top), garment(.top),
            garment(.bottom), garment(.bottom),
            garment(.footwear), garment(.footwear),
        ]
        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 3))

        #expect(suggestions.count >= 2)
        if let lead = suggestions.first {
            #expect(suggestions.allSatisfy { lead.score >= $0.score })
        }
    }

    @Test("Tiny wardrobes return all valid outfits without crashing")
    func tinyWardrobeIsSafe() async {
        let wardrobe = [garment(.top), garment(.bottom), garment(.footwear)]
        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 5))
        #expect(suggestions.count == 1)   // only one outfit is assemblable
    }
}
