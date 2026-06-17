//
//  SyntheticDebugImageProvider.swift
//  drape
//
//  DEBUG-ONLY. Deterministic, dependency-free image items for exercising the
//  import *plumbing* in CI without shipping any dataset. These are flat symbol
//  renders (via GarmentImageFactory), NOT real garment photos — autofill-quality
//  metrics over them are meaningless; use real CC0 images for that. They exist so
//  the importer and engine harness have something to run against on day one.
//

#if DEBUG
import Foundation

@MainActor
enum SyntheticDebugImageProvider {
    static let datasetID = "synthetic"

    /// `count` items spanning categories × palette in a fixed order. Ground truth
    /// is the exact category/color used to render each image, so the evaluator can
    /// at least measure color recovery deterministically.
    static func smokeItems(count: Int = 24) -> [DebugImageItem] {
        let categories = GarmentCategory.allCases
        let colors = ColorTag.allCases
        var items: [DebugImageItem] = []
        for i in 0..<count {
            let category = categories[i % categories.count]
            let color = colors[(i * 7) % colors.count]   // stride to vary the pairing
            guard let image = GarmentImageFactory.makeImage(category: category, color: color) else { continue }
            let id = String(format: "synthetic_%03d_%@_%@", i, category.rawValue, color.rawValue)
            items.append(DebugImageItem(
                id: id,
                imageData: image.imageData,
                groundTruth: DebugGroundTruth(
                    datasetID: datasetID,
                    rawCategory: category.rawValue,
                    category: category,
                    color: color)))
        }
        return items
    }
}
#endif
