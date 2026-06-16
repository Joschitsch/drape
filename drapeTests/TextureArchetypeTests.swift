//
//  TextureArchetypeTests.swift
//  drapeTests
//
//  Golden scenarios for the Phase 2 scorers (texture mix, archetype coherence)
//  and the free-form-style → archetype mapping that feeds the style vector.
//

import Foundation
import Testing
@testable import drape

@Suite("Texture mix scorer")
struct TextureMixTests {
    @Test("Unknown texture is neutral")
    func unknownIsNeutral() {
        let result = scoreTextureMix(
            garments: [garment(.top), garment(.bottom), garment(.footwear)],
            weather: nil)
        #expect(result.score == 0.5)
    }

    @Test("One rich texture beats a pile of heavy textures")
    func heroBeatsOverload() {
        let hero = [
            garment(.top, texture: .textured),
            garment(.bottom, texture: .smooth),
            garment(.footwear),
        ]
        let overload = [
            garment(.top, texture: .textured),
            garment(.bottom, texture: .textured),
            garment(.footwear),
        ]
        #expect(scoreTextureMix(garments: hero, weather: nil).score
                > scoreTextureMix(garments: overload, weather: nil).score)
    }

    @Test("Heavy-texture overload is forgiven in real cold")
    func coldForgivesOverload() {
        let overload = [
            garment(.top, texture: .textured),
            garment(.bottom, texture: .textured),
            garment(.footwear),
        ]
        let mild = scoreTextureMix(garments: overload, weather: WeatherSnapshot(temperatureCelsius: 18)).score
        let freezing = scoreTextureMix(garments: overload, weather: WeatherSnapshot(temperatureCelsius: 2)).score
        #expect(freezing > mild)
    }
}

@Suite("Archetype coherence scorer")
struct ArchetypeCoherenceTests {
    @Test("Too little signal stays neutral")
    func neutralWithoutSignal() {
        let result = scoreArchetypeCoherence(garments: [garment(.top, archetype: .classic), garment(.bottom)])
        #expect(result.score == 0.5)
    }

    @Test("A cohesive look outscores a mixed one and never drops below neutral")
    func cohesionRewardedSoftly() {
        let cohesive = [
            garment(.top, archetype: .minimalist),
            garment(.bottom, archetype: .minimalist),
            garment(.footwear, archetype: .minimalist),
        ]
        let mixed = [
            garment(.top, archetype: .boho),
            garment(.bottom, archetype: .sporty),
            garment(.footwear, archetype: .classic),
        ]
        let cohesiveScore = scoreArchetypeCoherence(garments: cohesive).score
        let mixedScore = scoreArchetypeCoherence(garments: mixed).score
        #expect(cohesiveScore > mixedScore)
        #expect(mixedScore >= 0.5)        // soft: contrast isn't punished
        #expect(cohesiveScore == 1.0)
    }

    @Test("Free-form styles feed the vector when no explicit archetype is set")
    func stylesMapIntoVector() {
        let viaStyles = [
            garment(.top, styles: ["minimal"]),
            garment(.bottom, styles: ["clean"]),     // also maps to minimalist
            garment(.footwear, styles: ["minimalist"]),
        ]
        #expect(scoreArchetypeCoherence(garments: viaStyles).score == 1.0)
    }
}

@Suite("Archetype mapping")
struct ArchetypeMappingTests {
    @Test("Built-in and synonym styles collapse onto the fixed set")
    func mapsKnownStyles() {
        #expect(Archetype.from(style: "minimal") == .minimalist)
        #expect(Archetype.from(style: "Old Money") == .preppy)
        #expect(Archetype.from(style: "bohemian") == .boho)
        #expect(Archetype.from(style: "grunge") == .edgy)
        #expect(Archetype.from(style: "wizard") == nil)
    }
}

@Suite("Heuristic archetype model")
struct HeuristicArchetypeModelTests {
    let model = HeuristicStyleArchetypeModel()

    @Test("User tags win over the label")
    func tagsWin() async {
        let result = await model.inferArchetype(
            descriptor: "leather jacket", category: .outerwear, styles: ["preppy"])
        #expect(result == .preppy)
    }

    @Test("Falls back to label keywords, else nil")
    func labelKeywords() async {
        let sporty = await model.inferArchetype(descriptor: "hoodie", category: .top, styles: [])
        #expect(sporty == .sporty)
        let unknown = await model.inferArchetype(descriptor: "thing", category: .top, styles: [])
        #expect(unknown == nil)
    }
}
