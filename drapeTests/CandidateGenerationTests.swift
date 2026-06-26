//
//  CandidateGenerationTests.swift
//  drapeTests
//
//  Candidate generation pre-ranks each slot and trims deterministically instead
//  of building the full cross product and randomly truncating it. These pin that
//  a clearly-best outfit is always considered, even in a large wardrobe, and that
//  a locked garment survives the cap.
//

import Foundation
import Testing
@testable import drape

@Suite("Candidate generation")
struct CandidateGenerationTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("A clearly-best outfit surfaces from a large wardrobe")
    func bestOutfitNotTruncated() async {
        // A pile of warm, dressy filler that's wrong for a hot casual day, plus
        // exactly one light, casual top/bottom/shoe that obviously fits. With the
        // old random truncation the good pieces could be dropped before scoring.
        var wardrobe: [GarmentSnapshot] = []
        for _ in 0..<15 {
            wardrobe.append(garment(.top, formality: .formal, warmth: .veryWarm))
            wardrobe.append(garment(.bottom, formality: .formal, warmth: .veryWarm))
            wardrobe.append(garment(.footwear, formality: .formal, warmth: .veryWarm))
        }
        let goodTop = garment(.top, formality: .casual, warmth: .light, color: .ivory)
        let goodBottom = garment(.bottom, formality: .casual, warmth: .light, color: .oat)
        let goodShoe = garment(.footwear, formality: .casual, warmth: .light, color: .ecru)
        wardrobe += [goodTop, goodBottom, goodShoe]

        let suggestions = await engine.recommend(
            context(wardrobe: wardrobe, occasion: .everyday, weather: hot28))

        // The light casual outfit should be the lead suggestion.
        let lead = suggestions.first
        #expect(lead != nil)
        #expect(lead!.garmentIDs.contains(goodTop.id))
        #expect(lead!.garmentIDs.contains(goodBottom.id))
        #expect(lead!.garmentIDs.contains(goodShoe.id))
    }

    @Test("A locked garment survives even when it pre-scores poorly")
    func lockedGarmentKeptDespiteLowFit() async {
        // The locked top was worn today, so its recency pre-score is the worst of
        // any top — it falls outside top-K. (Recency is a soft signal, not a hard
        // filter, so its outfits stay valid.) It must still be force-kept.
        let lockedTop = garment(.top, color: .burgundy)
        var wardrobe: [GarmentSnapshot] = [lockedTop]
        for _ in 0..<15 { wardrobe.append(garment(.top)) }  // fresh, otherwise identical
        wardrobe.append(garment(.bottom))
        wardrobe.append(garment(.footwear))

        let ctx = RecommendationContext(
            wardrobe: wardrobe,
            occasion: .everyday,
            recentWears: [lockedTop.id: Date.now],
            lockedGarmentID: lockedTop.id)
        let suggestions = await engine.recommend(ctx)

        #expect(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.garmentIDs.contains(lockedTop.id) })
    }
}
