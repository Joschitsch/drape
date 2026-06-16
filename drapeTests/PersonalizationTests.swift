//
//  PersonalizationTests.swift
//  drapeTests
//
//  Phase 4: "Style this piece" candidate locking, appetite-aware scorers, and
//  the bounded feedback-driven tuning.
//

import Foundation
import Testing
@testable import drape

@Suite("Style this piece")
struct StyleThisPieceTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Every suggestion contains the locked garment")
    func everySuggestionContainsLocked() async {
        let lockedTop = garment(.top, id: UUID())
        let wardrobe = [
            lockedTop,
            garment(.top),
            garment(.top),
            garment(.bottom),
            garment(.bottom),
            garment(.footwear),
        ]
        let ctx = RecommendationContext(
            wardrobe: wardrobe, occasion: .everyday, lockedGarmentID: lockedTop.id)
        let suggestions = await engine.recommend(ctx)

        #expect(!suggestions.isEmpty)
        for s in suggestions { #expect(s.garmentIDs.contains(lockedTop.id)) }
    }

    @Test("Locking a garment with no completion yields nothing")
    func unsatisfiableLockIsEmpty() async {
        let lockedDress = garment(.dress, id: UUID())
        // No footwear → dress can't be completed.
        let ctx = RecommendationContext(
            wardrobe: [lockedDress, garment(.top), garment(.bottom)],
            occasion: .everyday, lockedGarmentID: lockedDress.id)
        #expect(await engine.recommend(ctx).isEmpty)
    }
}

@Suite("Pattern tolerance")
struct PatternToleranceTests {
    @Test("Avoiders prefer solids; lovers prefer a pattern")
    func toleranceFlipsPreference() {
        let solids = [garment(.top, patternType: .solid), garment(.bottom, patternType: .solid), garment(.footwear, patternType: .solid)]
        let onePattern = [garment(.top, patternType: .floral), garment(.bottom, patternType: .solid), garment(.footwear, patternType: .solid)]

        // Avoider: solids win.
        #expect(scorePatternHarmony(garments: solids, tolerance: .avoid).score
                > scorePatternHarmony(garments: onePattern, tolerance: .avoid).score)
        // Lover: the pattern wins.
        #expect(scorePatternHarmony(garments: onePattern, tolerance: .love).score
                > scorePatternHarmony(garments: solids, tolerance: .love).score)
    }
}

@Suite("Relaxed silhouette preference")
struct RelaxedSilhouetteTests {
    @Test("Relaxed users aren't penalised for an all-soft, voluminous look")
    func relaxedForgivesVolume() {
        let slouchy = [
            garment(.top, fit: .oversized, structure: .soft),
            garment(.bottom, bottomVolume: .wide, structure: .soft),
            garment(.footwear),
        ]
        let strict = scoreVolumeBalance(garments: slouchy, prefersRelaxed: false).score
        let relaxed = scoreVolumeBalance(garments: slouchy, prefersRelaxed: true).score
        #expect(relaxed > strict)

        let strictStruct = scoreStructurePresence(garments: slouchy, occasion: .everyday, prefersRelaxed: false).score
        let relaxedStruct = scoreStructurePresence(garments: slouchy, occasion: .everyday, prefersRelaxed: true).score
        #expect(relaxedStruct > strictStruct)
    }
}

@Suite("Feedback tuning")
struct FeedbackTuningTests {
    @Test("'Too colorful' raises color/focal pressure, clamped")
    func tooColorfulTightens() {
        var tuning = StyleTuning()
        let before = tuning.multiplier(for: .focal)
        tuning.apply(reasons: [.tooColorful], positive: false)
        #expect(tuning.multiplier(for: .focal) > before)

        // Repeated feedback stays within the hard clamp.
        for _ in 0..<50 { tuning.apply(reasons: [.tooColorful], positive: false) }
        #expect(tuning.multiplier(for: .focal) <= StyleTuning.clampHigh)
    }

    @Test("'Not my silhouette' raises volume/structure weight")
    func silhouetteFeedback() {
        var tuning = StyleTuning()
        tuning.apply(reasons: [.notMySilhouette], positive: false)
        #expect(tuning.multiplier(for: .volume) > 1.0)
        #expect(tuning.multiplier(for: .structure) > 1.0)
    }

    @Test("'Too dressy' biases the formality target down, clamped to one level")
    func tooDressyLowersFormality() {
        var tuning = StyleTuning()
        for _ in 0..<10 { tuning.apply(reasons: [.tooDressy], positive: false) }
        #expect(tuning.formalityBias < 0)
        #expect(tuning.formalityBias >= -1)
    }

    @Test("Color appetite shifts the effective color multiplier")
    func appetiteShiftsMultiplier() {
        var neutral = StyleTuning(); neutral.colorAppetite = .neutrals
        var colorful = StyleTuning(); colorful.colorAppetite = .colorful
        #expect(neutral.multiplier(for: .color) > colorful.multiplier(for: .color))
    }
}

@Suite("Feedback changes engine output")
struct FeedbackEngineTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("A pattern-avoider ranks the all-solid outfit top")
    func avoiderPrefersSolids() async {
        let wardrobe = [
            garment(.top, color: .ink, patternType: .floral, patternScale: .large),
            garment(.top, color: .ink, patternType: .solid),
            garment(.bottom, color: .charcoal, patternType: .solid),
            garment(.footwear, color: .slate, patternType: .solid),
        ]
        var tuning = StyleTuning(); tuning.patternTolerance = .avoid
        let ctx = RecommendationContext(
            wardrobe: wardrobe, occasion: .everyday,
            profile: ProfilePreferences(tuning: tuning))

        let suggestions = await engine.recommend(ctx)
        let topOutfit = suggestions.first!.garmentIDs
        // The solid top should be the chosen one, not the floral.
        let solidTop = wardrobe.first { $0.category == .top && $0.patternType == .solid }!
        #expect(topOutfit.contains(solidTop.id))
    }
}
