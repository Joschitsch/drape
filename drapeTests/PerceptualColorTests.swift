//
//  PerceptualColorTests.swift
//  drapeTests
//
//  The perceptual color model that color harmony now reasons about: HSL
//  conversion, neutral detection, hue relationships, dominant-color extraction,
//  and proof that the engine reads a garment's true hex rather than its snapped
//  palette tag.
//

import Foundation
import Testing
@testable import drape

@Suite("PerceptualColor")
struct PerceptualColorTests {
    @Test("Primary hues convert from hex to HSL")
    func hslConversion() {
        #expect(abs(PerceptualColor(hex: "FF0000").hue - 0) < 1)
        #expect(abs(PerceptualColor(hex: "00FF00").hue - 120) < 1)
        #expect(abs(PerceptualColor(hex: "0000FF").hue - 240) < 1)

        let red = PerceptualColor(hex: "FF0000")
        #expect(abs(red.saturation - 1) < 0.001)
        #expect(abs(red.lightness - 0.5) < 0.001)
    }

    @Test("Greys and very muted colors read as neutral; vivid ones do not")
    func neutralDetection() {
        #expect(PerceptualColor(hex: "808080").isNeutral)   // mid grey
        #expect(PerceptualColor(hex: "FFFFFF").isNeutral)   // white
        #expect(PerceptualColor(hex: "23211D").isNeutral)   // ink
        #expect(PerceptualColor(hex: "3F4A3C").isNeutral)   // forest — desaturated green
        #expect(!PerceptualColor(hex: "FF0000").isNeutral)  // vivid red
        #expect(!PerceptualColor(hex: "A8563B").isNeutral)  // rust
    }

    @Test("Hue relationships classify analogous, complementary and clashing")
    func hueRelationships() {
        let red = PerceptualColor(hex: "FF0000")
        #expect(red.hueRelationship(to: PerceptualColor(hex: "FF4000")) == .analogous)     // orange-red
        #expect(red.hueRelationship(to: PerceptualColor(hex: "00FFFF")) == .complementary)  // cyan
        #expect(red.hueRelationship(to: PerceptualColor(hex: "00FF00")) == .clashing)        // green
    }

    @Test("Hue distance wraps around the wheel")
    func hueDistanceWraps() {
        let near0 = PerceptualColor(hex: "FF0000")              // 0°
        let near350 = PerceptualColor(hex: "FF0026")            // ~350°
        #expect(near0.hueDistance(to: near350) < 20)
    }

    @Test("Round-trips through hex")
    func hexRoundTrip() {
        #expect(PerceptualColor(hex: "A8563B").hex == "A8563B")
    }
}

@Suite("DominantColorExtractor")
struct DominantColorExtractorTests {
    private func samples(_ hex: String, _ count: Int) -> [PerceptualColor] {
        Array(repeating: PerceptualColor(hex: hex), count: count)
    }

    @Test("A red/white stripe yields red + white, not a muddy pink mean")
    func stripedYieldsBothColors() {
        let pixels = samples("FF0000", 60) + samples("FFFFFF", 40)
        let dominant = DominantColorExtractor().dominant(from: pixels, maxColors: 3)

        // Primary is genuinely red — a mean would have washed it to pink.
        let primary = dominant[0]
        #expect(primary.red > 0.6 && primary.green < 0.3 && primary.blue < 0.3)
        // White survives as a distinct secondary.
        #expect(dominant.contains { $0.red > 0.8 && $0.green > 0.8 && $0.blue > 0.8 })
    }

    @Test("A solid color collapses to a single cluster")
    func solidIsOneColor() {
        let dominant = DominantColorExtractor().dominant(from: samples("2C3A4F", 50), maxColors: 3)
        #expect(dominant.count == 1)
        #expect(dominant[0].hueDistance(to: PerceptualColor(hex: "2C3A4F")) < 5)
    }

    @Test("Clustering is order-independent")
    func orderIndependent() {
        let pixels = samples("FF0000", 30) + samples("0000FF", 30) + samples("FFFFFF", 30)
        let extractor = DominantColorExtractor()
        let a = extractor.clusters(from: pixels).map(\.color.hex).sorted()
        let b = extractor.clusters(from: pixels.shuffled()).map(\.color.hex).sorted()
        #expect(a == b)
    }
}

@Suite("Engine reads the true hex")
struct TrueHexHarmonyTests {
    @Test("A vivid custom color reads louder than its muted nearest tag")
    func customHexDrivesLoudness() {
        // `slate` is a near-neutral grey tag, but the garment's real color is a
        // vivid blue. The engine should see the vivid color, not the snapped tag.
        let snappedToNeutral = garment(.top, color: .slate)
        let trueVivid = garment(.top, color: .slate, colorHex: "1565E0")
        #expect(trueVivid.visualLoudness > snappedToNeutral.visualLoudness)
    }

    @Test("Two custom colors that clash score below two that harmonise")
    func customHexDrivesHarmony() {
        let clashing = [
            garment(.top, colorHex: "E0651A"),     // orange
            garment(.bottom, colorHex: "8E1FC0"),  // purple
            garment(.footwear, color: .ink),
        ]
        let analogous = [
            garment(.top, colorHex: "E0651A"),     // orange
            garment(.bottom, colorHex: "C0481F"),  // terracotta
            garment(.footwear, color: .ink),
        ]
        #expect(scoreColorHarmony(garments: clashing).score
                < scoreColorHarmony(garments: analogous).score)
    }
}
