//
//  FashionpediaTests.swift
//  drapeTests
//
//  Phase D: the Fashionpedia attribute mapping, the COCO ingestion (over a tiny
//  synthetic fixture — no multi-GB download in CI), and proof that attribute
//  accuracy lights up once ground truth is present.
//

#if DEBUG
import Foundation
import Testing
import UIKit
@testable import drape

@Suite("Fashionpedia attribute map")
struct FashionpediaAttributeMapTests {
    @Test("Categories map (reusing the dataset map + Fashionpedia extras)")
    func categories() {
        #expect(FashionpediaAttributeMap.category(forName: "pants") == .bottom)
        #expect(FashionpediaAttributeMap.category(forName: "dress") == .dress)
        #expect(FashionpediaAttributeMap.category(forName: "jacket") == .outerwear)
        #expect(FashionpediaAttributeMap.category(forName: "vest") == .top)        // extra
        #expect(FashionpediaAttributeMap.category(forName: "cape") == .outerwear)  // extra
        #expect(FashionpediaAttributeMap.category(forName: "tights, stockings") == .bottom) // extra
        #expect(FashionpediaAttributeMap.category(forName: "sleeve") == nil)       // a part — skipped
    }

    @Test("Pattern / silhouette / length / texture map from attribute names")
    func attributes() {
        #expect(FashionpediaAttributeMap.patternType(from: ["floral"]) == .floral)
        #expect(FashionpediaAttributeMap.patternType(from: ["striped"]) == .stripe)
        #expect(FashionpediaAttributeMap.patternType(from: ["plaid"]) == .check)
        #expect(FashionpediaAttributeMap.patternType(from: ["plain (pattern)"]) == .solid)
        #expect(FashionpediaAttributeMap.patternType(from: ["symmetrical"]) == nil)

        #expect(FashionpediaAttributeMap.bottomVolume(from: ["skinny"]) == .slim)
        #expect(FashionpediaAttributeMap.bottomVolume(from: ["wide leg (pants)"]) == .wide)
        #expect(FashionpediaAttributeMap.bottomVolume(from: ["straight (pants)"]) == .straight)

        #expect(FashionpediaAttributeMap.topLength(from: ["cropped (length)"]) == .cropped)
        #expect(FashionpediaAttributeMap.topLength(from: ["maxi (length)"]) == .long)

        #expect(FashionpediaAttributeMap.texture(from: ["cable knit"]) == .textured)
        #expect(FashionpediaAttributeMap.texture(from: ["leather"]) == .smooth)
    }
}

@MainActor
@Suite("Fashionpedia COCO source", .serialized)
struct FashionpediaCocoSourceTests {
    @Test("Parses a COCO file, crops the bbox, and maps ground truth")
    func parsesCropsMaps() throws {
        let fm = FileManager.default
        let dir = fm.temporaryDirectory.appendingPathComponent("fp_\(UUID().uuidString)")
        let imagesDir = dir.appendingPathComponent("val")
        try fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: dir) }

        // A 100×100 image to crop from.
        let img = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.systemTeal.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
        try img.pngData()!.write(to: imagesDir.appendingPathComponent("a.jpg"))

        // One pants annotation: wide-leg + striped.
        let json = """
        {"images":[{"id":1,"file_name":"a.jpg"}],
         "annotations":[{"id":10,"image_id":1,"category_id":6,"attribute_ids":[100,200],"bbox":[10,10,50,80]},
                        {"id":11,"image_id":1,"category_id":31,"attribute_ids":[],"bbox":[0,0,20,20]}],
         "categories":[{"id":6,"name":"pants"},{"id":31,"name":"sleeve"}],
         "attributes":[{"id":100,"name":"wide leg (pants)"},{"id":200,"name":"striped"}]}
        """
        let jsonURL = dir.appendingPathComponent("a.json")
        try json.write(to: jsonURL, atomically: true, encoding: .utf8)

        let items = FashionpediaCocoSource.load(jsonURL: jsonURL, imagesDir: imagesDir)

        #expect(items.count == 1)                       // the "sleeve" part is skipped
        let gt = items.first?.groundTruth
        #expect(gt?.category == .bottom)
        #expect(gt?.bottomVolume == .wide)
        #expect(gt?.patternType == .stripe)
        #expect(!(items.first?.imageData.isEmpty ?? true))
    }
}

@Suite("Attribute accuracy lights up with ground truth")
struct FashionpediaEvalTests {
    @Test("patternType reports accuracy once GT is present")
    func patternAccuracy() {
        let record = DebugImportRecord(
            sourceID: "x", garmentID: UUID(), split: .holdout,
            groundTruth: DebugGroundTruth(datasetID: "fp", patternType: .stripe),
            inferred: garment(.top, patternType: .stripe),
            classifierCategory: .top)
        let m = AttributeEval.evaluate([record], on: .holdout).metric("patternType")!
        #expect(m.accuracy != nil)        // was nil with clothing-dataset-small
        #expect(m.correct == 1)
    }
}
#endif
