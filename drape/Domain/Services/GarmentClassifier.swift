//
//  GarmentClassifier.swift
//  drape
//
//  Domain protocol: best-effort attribute guesses for a captured garment.
//

import Foundation

/// Proposes attributes (category, colors) for a freshly captured garment image
/// to pre-fill the add flow. Best-effort and non-throwing: returns
/// `ClassificationSuggestion.empty` when it can't decide.
///
/// The MVP uses simple heuristics (dominant-color analysis); this is the seam
/// where a Core ML category classifier slots in later.
protocol GarmentClassifier: Sendable {
    func classify(imageData: Data) async -> ClassificationSuggestion
}
