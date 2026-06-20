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

#if DEBUG
/// Raw masked-pixel statistics behind the numeric heuristics, surfaced only for the
/// ground-truth tuning loop. Lets the debug exporter record the exact features that
/// `textureGuess` / `patternGuess` / length / volume are computed from, so cutoffs
/// can be fit against ground truth instead of guessed.
struct ClassifierDiagnostics: Sendable {
    let luminanceStdDev: Double
    let edgeDensity: Double
    let aspect: Double
    let fillRatio: Double
}

/// DEBUG seam: a classifier that can also report the surface stats for an image.
protocol DiagnosticGarmentClassifier {
    func classifyWithDiagnostics(imageData: Data) async -> (ClassificationSuggestion, ClassifierDiagnostics?)
}
#endif
