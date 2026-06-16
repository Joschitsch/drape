//
//  SilhouettePatternTests.swift
//  drapeTests
//
//  Golden scenarios for the Phase 1 style-aware scorers: volume balance,
//  structure presence and pattern harmony. Pure functions, so these read as
//  plain input → expectation comparisons.
//

import Foundation
import Testing
@testable import drape

@Suite("Volume balance scorer")
struct VolumeBalanceTests {
    @Test("Unknown silhouette is neutral, never a penalty")
    func unknownIsNeutral() {
        let result = scoreVolumeBalance(garments: [garment(.top), garment(.bottom), garment(.footwear)])
        #expect(result.score == 0.5)
    }

    @Test("One voluminous piece beats two")
    func oneBeatsTwo() {
        let oneVolume = [
            garment(.top, fit: .oversized),
            garment(.bottom, bottomVolume: .slim),
            garment(.footwear),
        ]
        let twoVolume = [
            garment(.top, fit: .oversized),
            garment(.bottom, bottomVolume: .wide),
            garment(.footwear),
        ]
        #expect(scoreVolumeBalance(garments: oneVolume).score
                > scoreVolumeBalance(garments: twoVolume).score)
    }

    @Test("All-slim is fine but a single statement volume scores highest")
    func slimVsStatement() {
        let slim = [garment(.top, fit: .slim), garment(.bottom, bottomVolume: .slim), garment(.footwear)]
        let statement = [garment(.top, fit: .slim), garment(.bottom, bottomVolume: .wide), garment(.footwear)]
        #expect(scoreVolumeBalance(garments: statement).score
                > scoreVolumeBalance(garments: slim).score)
    }
}

@Suite("Structure presence scorer")
struct StructurePresenceTests {
    @Test("Unknown structure is neutral")
    func unknownIsNeutral() {
        let result = scoreStructurePresence(
            garments: [garment(.top), garment(.bottom), garment(.footwear)],
            occasion: .work)
        #expect(result.score == 0.5)
    }

    @Test("A tailored anchor outscores a head-to-toe soft look")
    func anchorBeatsSlouch() {
        let anchored = [
            garment(.top, structure: .soft),
            garment(.bottom, structure: .structured),
            garment(.footwear),
        ]
        let slouchy = [
            garment(.top, structure: .soft),
            garment(.bottom, structure: .soft),
            garment(.footwear),
        ]
        #expect(scoreStructurePresence(garments: anchored, occasion: .work).score
                > scoreStructurePresence(garments: slouchy, occasion: .work).score)
    }

    @Test("Sport ignores structure entirely")
    func sportIsNeutral() {
        let slouchy = [garment(.top, structure: .soft), garment(.bottom, structure: .soft), garment(.footwear)]
        #expect(scoreStructurePresence(garments: slouchy, occasion: .sport).score == 0.5)
    }
}

@Suite("Pattern harmony scorer")
struct PatternHarmonyTests {
    @Test("Unknown pattern is neutral")
    func unknownIsNeutral() {
        let result = scorePatternHarmony(garments: [garment(.top), garment(.bottom), garment(.footwear)])
        #expect(result.score == 0.5)
    }

    @Test("One hero pattern beats both all-solid and a clash")
    func heroBeatsSolidAndClash() {
        let solid = [
            garment(.top, patternType: .solid),
            garment(.bottom, patternType: .solid),
            garment(.footwear, patternType: .solid),
        ]
        let hero = [
            garment(.top, patternType: .floral),
            garment(.bottom, patternType: .solid),
            garment(.footwear, patternType: .solid),
        ]
        let clash = [
            garment(.top, patternType: .floral),
            garment(.bottom, patternType: .stripe),
            garment(.footwear, patternType: .check),
        ]
        let heroScore = scorePatternHarmony(garments: hero).score
        #expect(heroScore > scorePatternHarmony(garments: solid).score)
        #expect(heroScore > scorePatternHarmony(garments: clash).score)
    }

    @Test("Pattern read via scale alone, not just type")
    func scaleCountsAsPatterned() {
        let viaScale = [
            garment(.top, patternScale: .large),
            garment(.bottom, patternScale: PatternScale.none),
            garment(.footwear, patternScale: PatternScale.none),
        ]
        // One patterned piece (the large-scale top) → hero score.
        #expect(scorePatternHarmony(garments: viaScale).score == 1.0)
    }
}

@Suite("Style-aware scorers preserve appropriateness")
struct StyleScorerIntegrationTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Adding silhouette signal still returns valid, sorted suggestions")
    func engineStillRanks() async {
        let wardrobe = [
            garment(.top, fit: .regular, structure: .structured, patternType: .solid),
            garment(.top, fit: .oversized, topLength: .long, structure: .soft),
            garment(.bottom, bottomVolume: .straight, structure: .semiStructured, patternType: .solid),
            garment(.footwear),
        ]
        let suggestions = await engine.recommend(context(wardrobe: wardrobe, occasion: .everyday))
        #expect(!suggestions.isEmpty)
        for s in suggestions { #expect(s.score >= 0 && s.score <= 1) }
        #expect(suggestions.first!.score >= suggestions.last!.score)
    }
}
