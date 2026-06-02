//
//  StubRecommendationEngine.swift
//  drape
//
//  Step-1 placeholder. Replaced by RuleBasedRecommendationEngine later.
//

import Foundation

/// Returns no suggestions. The transparent rules-based engine (weather,
/// formality, color harmony, style, recency scorers) replaces it in the
/// recommendations step.
struct StubRecommendationEngine: RecommendationEngine {
    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion] {
        []
    }
}
