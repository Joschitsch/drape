//
//  ColorFocalTests.swift
//  drapeTests
//
//  Phase 3 scorers: refined color harmony (contrast + family cap + secondary
//  colors), visual loudness, the focal-point rule, and pattern-mix v2.
//

import Foundation
import Testing
@testable import drape

@Suite("Visual loudness")
struct VisualLoudnessTests {
    @Test("A neutral solid is quiet; a saturated large pattern is loud")
    func loudnessOrders() {
        let quiet = garment(.top, color: .ink, patternType: .solid)
        let loud = garment(.top, color: .rust, patternType: .floral, patternScale: .large)
        #expect(loud.visualLoudness > quiet.visualLoudness)
        #expect(quiet.visualLoudness < 0.4)
    }

    @Test("Secondary accents are counted by color harmony")
    func secondaryColorsCount() {
        // A garment that is neutral on top but carries two accent secondaries
        // should no longer read as a pure neutral palette.
        let withAccents = GarmentSnapshot(
            id: UUID(), category: .top, primaryColor: .ivory,
            secondaryColors: [.rust, .forest], formality: .casual, warmth: .light)
        let pureNeutral = [garment(.bottom, color: .charcoal), garment(.footwear, color: .ink)]
        let mixed = scoreColorHarmony(garments: [withAccents] + pureNeutral).score
        let clean = scoreColorHarmony(garments: [garment(.top, color: .ivory)] + pureNeutral).score
        #expect(clean > mixed)
    }
}

@Suite("Color harmony v2")
struct ColorHarmonyV2Tests {
    @Test("All-neutral still reads as the safe classic palette")
    func neutralStaysHigh() {
        let neutral = [garment(.top, color: .ivory), garment(.bottom, color: .charcoal), garment(.footwear, color: .ink)]
        #expect(scoreColorHarmony(garments: neutral).score >= 0.9)
    }

    @Test("Two clashing accent families are softly capped")
    func twoAccentsCapped() {
        let twoAccents = [
            garment(.top, color: .rust),       // warm
            garment(.bottom, color: .forest),  // cool
            garment(.footwear, color: .ink),
        ]
        #expect(scoreColorHarmony(garments: twoAccents).score <= 0.5)
    }

    @Test("Light/dark contrast scores above a flat tonal look")
    func contrastBeatsFlat() {
        let contrast = [garment(.top, color: .ivory), garment(.bottom, color: .ink), garment(.footwear, color: .ink)]
        let flat = [garment(.top, color: .ink), garment(.bottom, color: .ink), garment(.footwear, color: .ink)]
        #expect(scoreColorHarmony(garments: contrast).score > scoreColorHarmony(garments: flat).score)
    }
}

@Suite("Focal point scorer")
struct FocalPointTests {
    @Test("One hero beats both all-quiet and all-loud")
    func oneHeroWins() {
        let oneHero = [
            garment(.top, color: .rust, patternType: .floral, patternScale: .large),
            garment(.bottom, color: .ink),
            garment(.footwear, color: .charcoal),
        ]
        let allQuiet = [
            garment(.top, color: .ink),
            garment(.bottom, color: .charcoal),
            garment(.footwear, color: .slate),
        ]
        let allLoud = [
            garment(.top, color: .rust, patternType: .floral, patternScale: .large),
            garment(.bottom, color: .burgundy, patternType: .check, patternScale: .large),
            garment(.footwear, color: .denim, patternType: .stripe, patternScale: .large),
        ]
        let hero = scoreFocalPoint(garments: oneHero).score
        #expect(hero > scoreFocalPoint(garments: allQuiet).score)
        #expect(hero > scoreFocalPoint(garments: allLoud).score)
    }
}

@Suite("Pattern mix v2")
struct PatternMixV2Tests {
    @Test("Compatible two-pattern mix scores above an incompatible one")
    func compatibleMixIsForgiven() {
        // Same family + different scales = intentional mix.
        let compatible = [
            garment(.top, color: .ink, patternType: .stripe, patternScale: .small),
            garment(.bottom, color: .charcoal, patternType: .check, patternScale: .large),
            garment(.footwear, patternType: .solid),
        ]
        // Clashing families + same scale = harder.
        let incompatible = [
            garment(.top, color: .rust, patternType: .stripe, patternScale: .large),
            garment(.bottom, color: .forest, patternType: .check, patternScale: .large),
            garment(.footwear, patternType: .solid),
        ]
        #expect(scorePatternHarmony(garments: compatible).score
                > scorePatternHarmony(garments: incompatible).score)
    }
}
