//
//  EngineGoldenRuleTests.swift
//  drapeTests
//
//  Phase 3: qualitative "house style" rules the engine should hold over real-ish
//  wardrobes, plus adversarial monotonicity and the debug score-breakdown
//  invariant. Built on the same Fixtures helpers as the other golden suites.
//

import Foundation
import Testing
@testable import drape

@Suite("Engine house-style rules")
struct EngineGoldenRuleTests {
    let engine = RuleBasedRecommendationEngine()

    /// Resolves the top suggestion's core garments for a wardrobe.
    private func topCore(_ wardrobe: [GarmentSnapshot], _ ctx: RecommendationContext) async -> [GarmentSnapshot]? {
        let suggestions = await engine.recommend(ctx)
        guard let top = suggestions.first else { return nil }
        return coreGarments(resolve(top, in: wardrobe))
    }

    @Test("At most one large-scale pattern among core garments (non-sport)")
    func patternRestraint() async {
        let wardrobe = [
            garment(.top, color: .ink, patternType: .solid, patternScale: PatternScale.none),
            garment(.top, color: .rust, patternType: .floral, patternScale: .large),
            garment(.bottom, color: .charcoal, patternType: .solid, patternScale: PatternScale.none),
            garment(.bottom, color: .forest, patternType: .check, patternScale: .large),
            garment(.footwear, color: .slate, patternType: .solid, patternScale: PatternScale.none),
        ]
        let core = await topCore(wardrobe, context(wardrobe: wardrobe, occasion: .everyday))
        #expect(core != nil)
        #expect(core!.filter { $0.patternScale == .large }.count <= 1)
    }

    @Test("Work outfits include at least one structured core piece")
    func structurePresentForWork() async {
        let wardrobe = [
            garment(.top, formality: .business, structure: .soft),
            garment(.bottom, formality: .business, structure: .structured),  // the anchor
            garment(.bottom, formality: .business, structure: .soft),
            garment(.footwear, formality: .smartCasual),
        ]
        let core = await topCore(wardrobe, context(wardrobe: wardrobe, occasion: .work))
        #expect(core != nil)
        #expect(core!.contains { $0.structure?.isStructured == true })
    }

    @Test("No more than two loud core pieces compete in the top suggestion")
    func focalPointHolds() async {
        let wardrobe = [
            garment(.top, color: .rust, patternType: .floral, patternScale: .large),   // loud
            garment(.top, color: .ink, patternType: .solid, patternScale: PatternScale.none),  // quiet
            garment(.bottom, color: .burgundy, patternType: .check, patternScale: .large),     // loud
            garment(.bottom, color: .charcoal, patternType: .solid, patternScale: PatternScale.none),
            garment(.footwear, color: .denim, patternType: .stripe, patternScale: .large),      // loud
            garment(.footwear, color: .slate, patternType: .solid, patternScale: PatternScale.none),
        ]
        let core = await topCore(wardrobe, context(wardrobe: wardrobe, occasion: .everyday))
        #expect(core != nil)
        #expect(core!.filter { $0.visualLoudness > 0.55 }.count < 3)
    }

    @Test("Flipping a good outfit to an obviously bad one lowers its score")
    func adversarialMonotonicity() async {
        func outfit(texture: Texture, scale: PatternScale, fit: Fit) -> [GarmentSnapshot] {
            [
                garment(.top, fit: fit, structure: .structured, patternType: .abstract, patternScale: scale, texture: texture),
                garment(.bottom, fit: fit, structure: .structured, patternType: .check, patternScale: scale, texture: texture),
                garment(.footwear, patternType: .stripe, patternScale: scale, texture: texture),
            ]
        }
        let good = outfit(texture: .smooth, scale: PatternScale.none, fit: .regular)
        let bad = outfit(texture: .textured, scale: .large, fit: .oversized)

        let goodTop = await engine.recommend(context(wardrobe: good, occasion: .everyday)).first
        let badTop = await engine.recommend(context(wardrobe: bad, occasion: .everyday)).first
        #expect(goodTop != nil && badTop != nil)
        #expect(goodTop!.score > badTop!.score)
    }

    @Test("Canned contexts each return sorted, in-range suggestions")
    func cannedContextsRank() async {
        let wardrobe = [
            garment(.top, formality: .smartCasual, structure: .semiStructured, patternType: .solid),
            garment(.top, formality: .business, structure: .structured, patternType: .solid),
            garment(.bottom, formality: .smartCasual, structure: .semiStructured, patternType: .solid),
            garment(.footwear, formality: .smartCasual),
            garment(.outerwear, formality: .business, warmth: .warm, structure: .structured),
        ]
        let canned: [(Occasion, WeatherSnapshot)] = [
            (.everyday, WeatherSnapshot(temperatureCelsius: 25)),
            (.work, WeatherSnapshot(temperatureCelsius: 18)),
            (.date, WeatherSnapshot(temperatureCelsius: 22)),
        ]
        for (occasion, weather) in canned {
            let suggestions = await engine.recommend(
                context(wardrobe: wardrobe, occasion: occasion, weather: weather))
            for s in suggestions { #expect(s.score >= 0 && s.score <= 1) }
            #expect(suggestions.map(\.score) == suggestions.map(\.score).sorted(by: >))
        }
    }
}

#if DEBUG
@Suite("Debug score breakdown")
struct ScoreBreakdownTests {
    let engine = RuleBasedRecommendationEngine()

    @Test("Breakdown reproduces each suggestion's score exactly")
    func breakdownMatchesScore() async {
        let wardrobe = [
            garment(.top, color: .navy, structure: .structured, patternType: .solid, texture: .smooth, archetype: .classic),
            garment(.bottom, color: .charcoal, structure: .semiStructured, patternType: .solid, texture: .subtleTexture),
            garment(.footwear, color: .ivory),
            garment(.outerwear, warmth: .warm, color: .camel, structure: .structured),
        ]
        let ctx = context(wardrobe: wardrobe, occasion: .everyday, weather: WeatherSnapshot(temperatureCelsius: 16))

        let suggestions = await engine.recommend(ctx)
        let breakdown = await engine.scoreBreakdown(ctx)

        #expect(breakdown.count == suggestions.count)
        for (b, s) in zip(breakdown, suggestions) {
            #expect(b.garmentIDs == s.garmentIDs)
            #expect(abs(b.normalized - s.score) < 1e-9)
            #expect(b.contributions.count == 12)            // every scorer represented
        }
    }
}
#endif
