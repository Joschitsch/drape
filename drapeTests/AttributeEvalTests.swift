//
//  AttributeEvalTests.swift
//  drapeTests
//
//  Phase 2: the autofill evaluator's accuracy/coverage/confusion math and the
//  dataset label mapping. Pure and deterministic — no images, no SwiftData.
//

#if DEBUG
import Foundation
import Testing
@testable import drape

@Suite("Attribute evaluation")
struct AttributeEvalTests {
    private func record(
        id: String,
        split: DebugSplit = .holdout,
        gtCategory: GarmentCategory? = nil,
        gtColor: ColorTag? = nil,
        classifierCategory: GarmentCategory?,
        inferredColor: ColorTag = .ink
    ) -> DebugImportRecord {
        DebugImportRecord(
            sourceID: id,
            garmentID: UUID(),
            split: split,
            groundTruth: DebugGroundTruth(datasetID: "t", category: gtCategory, color: gtColor),
            inferred: garment(.top, color: inferredColor),
            classifierCategory: classifierCategory,
            categoryConfidence: 0.9)
    }

    @Test("Category accuracy and coverage count correctly")
    func categoryMetrics() {
        let records = [
            record(id: "a", gtCategory: .top, classifierCategory: .top),       // correct
            record(id: "b", gtCategory: .bottom, classifierCategory: .top),    // wrong
            record(id: "c", gtCategory: .footwear, classifierCategory: nil),   // uncovered
        ]
        let report = AttributeEval.evaluate(records, on: .holdout)
        let cat = report.metric("category")!
        #expect(cat.evaluated == 3)
        #expect(cat.covered == 2)
        #expect(cat.correct == 1)
        #expect(abs(cat.accuracy - 0.5) < 1e-9)              // 1 of 2 covered
        #expect(abs(cat.coverage - 2.0 / 3.0) < 1e-9)
    }

    @Test("Color is judged at family granularity")
    func colorFamilyMetric() {
        let records = [
            record(id: "a", gtColor: .navy, classifierCategory: .top, inferredColor: .denim),   // both cool → correct
            record(id: "b", gtColor: .rust, classifierCategory: .top, inferredColor: .ink),      // warm vs neutral → wrong
        ]
        let report = AttributeEval.evaluate(records, on: .holdout)
        let col = report.metric("colorFamily")!
        #expect(col.correct == 1)
        #expect(col.covered == 2)
    }

    @Test("Evaluation is restricted to the chosen split")
    func respectsSplit() {
        let records = [
            record(id: "a", split: .dev, gtCategory: .top, classifierCategory: .bottom),
            record(id: "b", split: .holdout, gtCategory: .top, classifierCategory: .top),
        ]
        let report = AttributeEval.evaluate(records, on: .holdout)
        #expect(report.total == 1)                          // dev record excluded
        #expect(report.metric("category")!.correct == 1)
    }

    @Test("Misses surface in the confusion list")
    func confusionList() {
        let records = [record(id: "miss", gtCategory: .footwear, classifierCategory: .accessory)]
        let report = AttributeEval.evaluate(records, on: .holdout)
        #expect(report.confusions.contains {
            $0.sourceID == "miss" && $0.expected == "footwear" && $0.got == "accessory"
        })
    }
}

@Suite("Dataset label mapping")
struct DatasetLabelMapTests {
    @Test("Article types map to our categories")
    func categoryMapping() {
        #expect(DatasetLabelMap.category(forArticleType: "Tshirts") == .top)
        #expect(DatasetLabelMap.category(forArticleType: "Jeans") == .bottom)
        #expect(DatasetLabelMap.category(forArticleType: "Casual Shoes") == .footwear)
        #expect(DatasetLabelMap.category(forArticleType: "Watches") == .accessory)
        #expect(DatasetLabelMap.category(forArticleType: "Dresses") == .dress)
        #expect(DatasetLabelMap.category(forArticleType: "Jackets") == .outerwear)
        #expect(DatasetLabelMap.category(forArticleType: "Quasar") == nil)
    }

    @Test("Color names map to nearest palette tag")
    func colorMapping() {
        #expect(DatasetLabelMap.color(forName: "Navy Blue") == .navy)
        #expect(DatasetLabelMap.color(forName: "Black") == .ink)
        #expect(DatasetLabelMap.color(forName: "Off White") == .ivory)
        #expect(DatasetLabelMap.color(forName: "Maroon") == .burgundy)
        #expect(DatasetLabelMap.color(forName: "Fluorescent") == nil)
    }

    @Test("Builds typed ground truth from raw row fields")
    func buildsGroundTruth() {
        let gt = DatasetLabelMap.groundTruth(datasetID: "fpi", rawCategory: "Tshirts", rawColor: "Navy Blue")
        #expect(gt.category == .top)
        #expect(gt.color == .navy)
        #expect(gt.rawCategory == "Tshirts")
    }
}
#endif
