//
//  RuleBasedRecommendationEngine.swift
//  drape
//
//  Transparent rules-based outfit ranker. Isolated behind RecommendationEngine
//  so a Core ML or LLM-backed version can slot in without touching the UI.
//

import Foundation

struct RuleBasedRecommendationEngine: RecommendationEngine {
    // Scorer weights (sum doesn't need to equal 1; scores are normalised below).
    private let weights: Weights

    struct Weights {
        var warmth:    Double = 1.5
        var formality: Double = 1.5
        var color:     Double = 1.0
        var style:     Double = 1.0
        var recency:   Double = 0.8
        var season:    Double = 0.8
        var rain:      Double = 0.6
    }

    init(weights: Weights = Weights()) {
        self.weights = weights
    }

    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion] {
        let candidates = buildCandidates(from: context.wardrobe)
        guard !candidates.isEmpty else { return [] }

        var scored: [(garments: [GarmentSnapshot], score: Double, rationale: [String])] = []

        for candidate in candidates {
            let warmthResult = scoreWarmth(garments: candidate, weather: context.weather)
            // Hard filter: never recommend an outfit that is temperature-wrong.
            if context.weather != nil && warmthResult.score == 0 { continue }

            // Hard filter: drop outfits whose formality is too far from the
            // occasion's target. Uses user-defined per-occasion preferences when
            // available, falling back to hardcoded occasion defaults.
            let userOccasionPref = context.profile.occasionPreference(for: context.occasion)
            let formalityTarget = userOccasionPref.map { Double($0.targetFormality.rawValue) }
                ?? Double(context.occasion.targetFormality.rawValue)
            let formalityTolerance = userOccasionPref != nil ? 1.5 : context.occasion.formalityTolerance
            let core = candidate.filter {
                $0.category.slot != .accessory && $0.category.slot != .outerwear
            }
            if !core.isEmpty {
                let avgFormality = Double(core.map { $0.formality.rawValue }.reduce(0, +))
                    / Double(core.count)
                let formalityDist = abs(avgFormality - formalityTarget)
                if formalityDist > formalityTolerance { continue }
            }

            var totalWeight = 0.0
            var weightedScore = 0.0
            var rationale: [String] = []

            func add(weight: Double, result: (score: Double, rationale: String?)) {
                weightedScore += result.score * weight
                totalWeight   += weight
                if let r = result.rationale { rationale.append(r) }
            }

            add(weight: weights.warmth,    result: warmthResult)
            add(weight: weights.formality, result: scoreFormality(garments: candidate, occasion: context.occasion, profile: context.profile))
            add(weight: weights.color,     result: scoreColorHarmony(garments: candidate))
            add(weight: weights.style,     result: scoreStyleMatch(garments: candidate, profile: context.profile, occasion: context.occasion))
            add(weight: weights.recency,   result: scoreRecency(garments: candidate, recentWears: context.recentWears))
            add(weight: weights.season,    result: scoreSeason(garments: candidate, season: context.season))
            add(weight: weights.rain,      result: scoreRainReadiness(garments: candidate, weather: context.weather))

            let normalized = totalWeight > 0 ? weightedScore / totalWeight : 0
            scored.append((candidate, normalized, rationale))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(context.desiredCount)
            .map { OutfitSuggestion(garmentIDs: $0.garments.map(\.id), score: $0.score, rationale: $0.rationale) }
    }

    // MARK: - Candidate generation

    /// Enumerates valid outfit combinations:
    ///   - (top, bottom, footwear) with optional outerwear
    ///   - (dress, footwear) with optional outerwear
    /// Combinations are sampled to keep them tractable at large wardrobe sizes.
    private func buildCandidates(from wardrobe: [GarmentSnapshot]) -> [[GarmentSnapshot]] {
        let tops      = wardrobe.filter { $0.category == .top }
        let bottoms   = wardrobe.filter { $0.category == .bottom }
        let dresses   = wardrobe.filter { $0.category == .dress }
        let footwear  = wardrobe.filter { $0.category == .footwear }
        let outerwear = wardrobe.filter { $0.category == .outerwear }

        // Optional layers: nil (no outerwear) plus each outerwear item.
        let outerOptions: [GarmentSnapshot?] = [nil] + outerwear.map { Optional($0) }

        var candidates: [[GarmentSnapshot]] = []

        // top + bottom combinations
        for top in tops {
            for bottom in bottoms {
                for shoe in footwear {
                    for outer in outerOptions {
                        var combo: [GarmentSnapshot] = [top, bottom, shoe]
                        if let outer { combo.append(outer) }
                        candidates.append(combo)
                    }
                }
            }
        }

        // dress combinations
        for dress in dresses {
            for shoe in footwear {
                for outer in outerOptions {
                    var combo: [GarmentSnapshot] = [dress, shoe]
                    if let outer { combo.append(outer) }
                    candidates.append(combo)
                }
            }
        }

        // Cap at 200 candidates (shuffle so we don't always pick the same items
        // when the wardrobe is large).
        if candidates.count > 200 {
            candidates.shuffle()
            candidates = Array(candidates.prefix(200))
        }
        return candidates
    }
}
