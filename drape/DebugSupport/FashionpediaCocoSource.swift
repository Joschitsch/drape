//
//  FashionpediaCocoSource.swift
//  drape
//
//  DEBUG-ONLY. Reads Fashionpedia's COCO `instances_attributes` JSON + images
//  into DebugImageItems for the importer. Fashionpedia is on-model/full-scene, so
//  a plain bbox crop would still contain the person and adjacent garments. Instead
//  we use each annotation's *ground-truth polygon* to cut out only that garment and
//  composite it on the neutral canvas — yielding a clean isolated garment that
//  matches the app's real input (individual garment shots). Annotations without a
//  polygon (RLE, ~3%) are skipped so the measurement isn't polluted.
//
//  Licensing: annotations are CC BY 4.0 (what we score against); images are used
//  locally for measurement only — never committed or shipped. See Tools/FASHIONPEDIA.md.
//

#if DEBUG
import Foundation
import UIKit

@MainActor
enum FashionpediaCocoSource {
    static let datasetID = "fashionpedia"

    /// Matches `VisionImageProcessingService.canvasColor` so the importer's
    /// re-normalisation is a no-op on these already-isolated garments.
    private static let canvas = UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)

    private struct Coco: Decodable {
        struct Image: Decodable { let id: Int; let file_name: String }
        struct Annotation: Decodable {
            let id: Int; let image_id: Int; let category_id: Int
            let attribute_ids: [Int]?; let bbox: [Double]
            /// COCO polygon segmentation `[[x,y,…]]`; nil when the annotation uses
            /// RLE (a dict) or omits segmentation.
            let polygons: [[Double]]?

            enum CodingKeys: String, CodingKey {
                case id, image_id, category_id, attribute_ids, bbox, segmentation
            }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: CodingKeys.self)
                id = try c.decode(Int.self, forKey: .id)
                image_id = try c.decode(Int.self, forKey: .image_id)
                category_id = try c.decode(Int.self, forKey: .category_id)
                attribute_ids = try c.decodeIfPresent([Int].self, forKey: .attribute_ids)
                bbox = try c.decode([Double].self, forKey: .bbox)
                polygons = try? c.decode([[Double]].self, forKey: .segmentation)  // nil for RLE
            }
        }
        struct Named: Decodable { let id: Int; let name: String }
        let images: [Image]
        let annotations: [Annotation]
        let categories: [Named]
        let attributes: [Named]
    }

    /// Loads up to `perCategoryLimit` isolated-garment cutouts per mapped category.
    /// Deterministic (sorted by annotation id); split left to the importer's hash.
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
                  let polygons = ann.polygons, !polygons.isEmpty,   // skip RLE / segless
                  let file = fileByImageID[ann.image_id],
                  let cutout = garmentCutout(imagesDir.appendingPathComponent(file),
                                             bbox: ann.bbox, polygons: polygons)
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
                imageData: cutout,
                groundTruth: groundTruth))
            perCategoryCount[category, default: 0] += 1
        }
        return items.sorted { $0.id < $1.id }
    }

    /// Cuts out just the polygon region from the source image and composites it on
    /// the neutral canvas, sized to the (clamped) bbox. Returns PNG data.
    private static func garmentCutout(_ imageURL: URL, bbox: [Double], polygons: [[Double]]) -> Data? {
        guard bbox.count == 4, let cg = UIImage(contentsOfFile: imageURL.path)?.cgImage else { return nil }
        let imgW = CGFloat(cg.width), imgH = CGFloat(cg.height)
        let bx = max(0, CGFloat(bbox[0])), by = max(0, CGFloat(bbox[1]))
        let bw = min(CGFloat(bbox[2]), imgW - bx), bh = min(CGFloat(bbox[3]), imgH - by)
        guard bw >= 8, bh >= 8 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: bw, height: bh))
        let image = renderer.image { _ in
            canvas.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: bw, height: bh))

            // Clip to the garment outline, translated into bbox-local coordinates.
            let path = UIBezierPath()
            for poly in polygons where poly.count >= 6 {
                var pts: [CGPoint] = []
                var i = 0
                while i + 1 < poly.count {
                    pts.append(CGPoint(x: CGFloat(poly[i]) - bx, y: CGFloat(poly[i + 1]) - by))
                    i += 2
                }
                path.move(to: pts[0])
                pts.dropFirst().forEach { path.addLine(to: $0) }
                path.close()
            }
            guard !path.isEmpty else { return }
            path.usesEvenOddFillRule = true
            path.addClip()
            UIImage(cgImage: cg).draw(at: CGPoint(x: -bx, y: -by))
        }
        return image.pngData()
    }
}
#endif
