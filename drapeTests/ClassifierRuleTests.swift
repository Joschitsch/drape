//
//  ClassifierRuleTests.swift
//  drapeTests
//
//  A3: warmth / formality / seasons (and the fit/structure/weight priors) aren't
//  pixel-inferred — they're a deterministic lookup from the detected label in
//  VisionGarmentClassifier. They feed the engine's hard filters, so the rule
//  table itself is pinned here. Pure, no Vision, no dataset.
//

import Foundation
import Testing
@testable import drape

@Suite("Classifier label rules")
struct ClassifierRuleTests {
    @Test("Representative labels map to sensible warmth / formality / seasons")
    func labelProperties() {
        let puffer = VisionGarmentClassifier.properties(for: "puffer")
        #expect(puffer?.category == .outerwear)
        #expect(puffer?.warmth == .veryWarm)
        #expect(puffer?.seasons.contains(.winter) == true)

        let tee = VisionGarmentClassifier.properties(for: "t-shirt")
        #expect(tee?.category == .top)
        #expect(tee?.warmth == .light)
        #expect(tee?.formality == .casual)
        #expect(tee?.seasons.contains(.summer) == true)

        let shirt = VisionGarmentClassifier.properties(for: "dress shirt")
        #expect(shirt?.formality == .business)

        let trench = VisionGarmentClassifier.properties(for: "trench")
        #expect(trench?.category == .outerwear)
        #expect(trench?.warmth == .warm)

        #expect(VisionGarmentClassifier.properties(for: "quux zonk") == nil)

        // Core ML class labels all resolve (so the model's output maps cleanly).
        #expect(VisionGarmentClassifier.properties(for: "longsleeve")?.category == .top)
        #expect(VisionGarmentClassifier.properties(for: "outwear")?.category == .outerwear)
    }

    /// The retrained category model emits these fine-grained labels (the canonical
    /// vocabulary in Tools/build_training_data.py). Every one MUST resolve through
    /// `properties(for:)` to the expected category — that lookup is how the model's
    /// prediction becomes warmth/formality/seasons, so an unmapped label would
    /// silently drop those axes. This pins the model ↔ rule-table contract.
    @Test("Every canonical category-model label resolves to its expected category")
    func canonicalVocabularyResolves() {
        let expected: [String: GarmentCategory] = [
            "t-shirt": .top, "shirt": .top, "blouse": .top, "tank": .top,
            "sweater": .top, "sweatshirt": .top,
            "jacket": .outerwear, "blazer": .outerwear,
            "jeans": .bottom, "trousers": .bottom, "shorts": .bottom,
            "skirt": .bottom, "leggings": .bottom,
            "dress": .dress, "jumpsuit": .dress,
            "sneaker": .footwear, "sandal": .footwear,
            "high heel": .footwear, "loafer": .footwear,
            "handbag": .accessory, "backpack": .accessory,
            "cap": .accessory, "hat": .accessory, "sunglasses": .accessory,
            "scarf": .accessory, "tie": .accessory, "belt": .accessory,
        ]
        for (label, category) in expected {
            #expect(VisionGarmentClassifier.properties(for: label)?.category == category,
                    "label '\(label)' should map to \(category)")
        }
    }

    @Test("Style-default priors are sensible per label")
    func stylePriors() {
        let blazer = VisionGarmentClassifier.styleDefaults(label: "blazer", category: .outerwear)
        #expect(blazer.structure == .structured)

        let hoodie = VisionGarmentClassifier.styleDefaults(label: "hoodie", category: .top)
        #expect(hoodie.fit == .relaxed)
        #expect(hoodie.structure == .soft)

        let legging = VisionGarmentClassifier.styleDefaults(label: "legging", category: .bottom)
        #expect(legging.fit == .slim)
        #expect(legging.weight == .light)

        // Unknown label falls back to the category default (a top is soft/light).
        let unknownTop = VisionGarmentClassifier.styleDefaults(label: "zzz", category: .top)
        #expect(unknownTop.structure == .soft)
    }
}

#if DEBUG
@Suite("Dataset usage/season mapping")
struct DatasetUsageSeasonTests {
    @Test("Usage maps to formality, season name to Season")
    func mapsUsageAndSeason() {
        #expect(DatasetLabelMap.formality(forUsage: "Formal") == .formal)
        #expect(DatasetLabelMap.formality(forUsage: "Casual") == .casual)
        #expect(DatasetLabelMap.season(forName: "Fall") == .autumn)
        #expect(DatasetLabelMap.season(forName: "Summer") == .summer)

        let gt = DatasetLabelMap.groundTruth(
            datasetID: "fpi", rawCategory: "Shirts", rawColor: "Navy Blue",
            rawUsage: "Formal", rawSeason: "Winter")
        #expect(gt.formality == .formal)
        #expect(gt.season == .winter)
    }
}
#endif
