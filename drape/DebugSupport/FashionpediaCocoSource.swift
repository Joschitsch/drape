//
//  FashionpediaCocoSource.swift
//  drape
//
//  DEBUG-ONLY. Reads Fashionpedia's COCO `instances_attributes` JSON + images
//  into DebugImageItems for the importer. Each garment *annotation* (not the whole
//  image) becomes one item: its bbox is cropped out and its CC-BY attributes are
//  mapped to ground truth (pattern / bottom volume / top length / texture). Parts
//  (sleeve, collar, …) don't map to a GarmentCategory and are skipped.
//
//  Licensing: the annotations are CC BY 4.0 (what we score against). The images
//  are mixed per-source — used locally for measurement only, never committed or
//  shipped. Point this at a locally-downloaded Fashionpedia folder.
//

#if DEBUG
import Foundation
import UIKit

@MainActor
enum FashionpediaCocoSource {
    static let datasetID = "fashionpedia"

    private struct Coco: Decodable {
        struct Image: Decodable { let id: Int; let file_name: String }
        struct Annotation: Decodable {
            let id: Int; let image_id: Int; let category_id: Int
            let attribute_ids: [Int]?; let bbox: [Double]
        }
        struct Named: Decodable { let id: Int; let name: String }
        let images: [Image]
        let annotations: [Annotation]
        let categories: [Named]
        let attributes: [Named]
    }

    /// Loads up to `perCategoryLimit` garment crops per mapped category from a
    /// Fashionpedia COCO JSON and its images directory. Deterministic (sorted by
    /// annotation id); split left to the importer's stable hash.
    static func load(jsonURL: URL, imagesDir: URL, perCategoryLimit: Int = 25) -> [DebugImageItem] {
        guard let data = try? Data(contentsOf: jsonURL),
              let coco = try? JSONDecoder().decode(Coco.self, from: data) else { return [] }

        let fileByImageID = Dictionary(coco.images.map { ($0.id, $0.file_name) }, uniquingKeysWith: { a, _ in a })
        let categoryName = Dictionary(coco.categories.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let attributeName = Dictionary(coco.attributes.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })

        var perCategoryCount: [GarmentCategory: Int] = [:]
        var items: [DebugImageItem] = []

        for ann in coco.annotations.sorted(by: { $0.id < $1.id }) {
            guard let rawCat = categoryName[ann.category_id],
                  let category = FashionpediaAttributeMap.category(forName: rawCat),
                  perCategoryCount[category, default: 0] < perCategoryLimit,
                  let file = fileByImageID[ann.image_id],
                  let cropped = crop(imagesDir.appendingPathComponent(file), bbox: ann.bbox)
            else { continue }

            let names = (ann.attribute_ids ?? []).compactMap { attributeName[$0] }
            let groundTruth = DebugGroundTruth(
                datasetID: datasetID,
                rawCategory: rawCat,
                category: category,
                patternType: FashionpediaAttributeMap.patternType(from: names),
                bottomVolume: category == .bottom ? FashionpediaAttributeMap.bottomVolume(from: names) : nil,
                topLength: (category == .top || category == .dress) ? FashionpediaAttributeMap.topLength(from: names) : nil,
                texture: FashionpediaAttributeMap.texture(from: names))

            items.append(DebugImageItem(
                id: String(format: "%07d_%@", ann.id, rawCat.replacingOccurrences(of: " ", with: "_")),
                imageData: cropped,
                groundTruth: groundTruth))
            perCategoryCount[category, default: 0] += 1
        }
        return items.sorted { $0.id < $1.id }
    }

    /// Crops the bbox region [x, y, w, h] (clamped to the image) and returns PNG.
    private static func crop(_ imageURL: URL, bbox: [Double]) -> Data? {
        guard bbox.count == 4, let cg = UIImage(contentsOfFile: imageURL.path)?.cgImage else { return nil }
        let rect = CGRect(x: bbox[0], y: bbox[1], width: bbox[2], height: bbox[3])
            .intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !rect.isNull, rect.width >= 8, rect.height >= 8,
              let cropped = cg.cropping(to: rect) else { return nil }
        return UIImage(cgImage: cropped).pngData()
    }
}
#endif
