//
//  RecommendationEngine.swift
//  drape
//
//  Domain protocol: produce ranked outfit suggestions.
//

import Foundation

/// Produces ranked outfit suggestions from a self-contained context. The MVP is
/// a transparent rules-based engine; this protocol is the seam for swapping in a
/// Core ML model or a remote LLM later without touching the UI.
///
/// `async` so future remote/model-backed implementations fit the same shape.
protocol RecommendationEngine: Sendable {
    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion]
}
