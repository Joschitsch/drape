//
//  StubGarmentClassifier.swift
//  drape
//
//  Step-1 placeholder. Replaced by HeuristicGarmentClassifier later.
//

import Foundation

/// Always returns an empty suggestion, so the add flow falls back to manual
/// entry. The heuristic (dominant-color) classifier replaces it in the
/// wardrobe-capture step.
struct StubGarmentClassifier: GarmentClassifier {
    func classify(imageData: Data) async -> ClassificationSuggestion {
        .empty
    }
}
