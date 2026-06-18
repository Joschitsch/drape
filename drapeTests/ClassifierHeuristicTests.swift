//
//  ClassifierHeuristicTests.swift
//  drapeTests
//
//  A1: the category-independent surface heuristics (pattern / texture) the
//  classifier derives from the mask. Pure functions over SurfaceStats, so they're
//  tested without running Vision — and they prove these axes are produced
//  regardless of whether category classification succeeds.
//

import Foundation
import Testing
@testable import drape

@Suite("Classifier surface heuristics")
struct ClassifierHeuristicTests {
    private func stats(std: Double, edge: Double, aspect: Double = 1.2, fill: Double = 0.5)
        -> VisionGarmentClassifier.SurfaceStats {
        .init(aspect: aspect, fillRatio: fill, luminanceStdDev: std, edgeDensity: edge)
    }

    @Test("Calm surface reads solid; busy high-contrast surface reads patterned")
    func patternGuess() {
        let solid = VisionGarmentClassifier.patternGuess(stats(std: 0.03, edge: 0.02))
        #expect(solid.type == .solid)
        #expect(solid.scale == PatternScale.none)

        // High spread + dense edges → patterned, fine scale, kind left unknown.
        let busy = VisionGarmentClassifier.patternGuess(stats(std: 0.20, edge: 0.15))
        #expect(busy.type == nil)
        #expect(busy.scale == .small)

        // Patterned but broad, low-frequency edges → large scale.
        let broad = VisionGarmentClassifier.patternGuess(stats(std: 0.20, edge: 0.07))
        #expect(broad.scale == .large)
    }

    @Test("Texture maps from brightness spread and always yields a value")
    func textureGuess() {
        #expect(VisionGarmentClassifier.textureGuess(stats(std: 0.02, edge: 0)) == .smooth)
        #expect(VisionGarmentClassifier.textureGuess(stats(std: 0.08, edge: 0)) == .subtleTexture)
        #expect(VisionGarmentClassifier.textureGuess(stats(std: 0.20, edge: 0)) == .textured)
    }

    @Test("Pattern and texture are produced for any valid stats (category-independent)")
    func alwaysProduced() {
        for std in stride(from: 0.0, through: 0.3, by: 0.05) {
            for edge in stride(from: 0.0, through: 0.2, by: 0.05) {
                let s = stats(std: std, edge: edge)
                // texture is non-optional; pattern always resolves a scale.
                _ = VisionGarmentClassifier.textureGuess(s)
                #expect(VisionGarmentClassifier.patternGuess(s).scale != nil)
            }
        }
    }
}
