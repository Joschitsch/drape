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
        var rain:      Double = 0.6
        // Silhouette / fabric / pattern axes. Kept below the warmth/formality
        // floors so they refine ties between otherwise-appropriate outfits
        // rather than override appropriateness.
        var volume:    Double = 0.7
        var structure: Double = 0.5
        var pattern:   Double = 0.7
        var texture:   Double = 0.5
        var archetype: Double = 0.6
        var focal:     Double = 0.8
    }

    init(weights: Weights = Weights()) {
        self.weights = weights
    }

    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion] {
        let candidates = buildCandidates(from: context.wardrobe,
                                         lockedGarmentID: context.lockedGarmentID)
        guard !candidates.isEmpty else { return [] }

        // Per-user personalisation: appetites + clamped feedback nudges.
        let tuning = context.profile.tuning

        var scored: [(garments: [GarmentSnapshot], score: Double, rationale: [String])] = []

        for candidate in candidates {
            let warmthResult = scoreWarmth(garments: candidate, weather: context.weather)
            // Hard filter: never recommend an outfit that is temperature-wrong.
            if context.weather != nil && warmthResult.score == 0 { continue }

            // Hard filter: every core garment must individually sit within the
            // occasion's formality tolerance of the target — no averaging, so a
            // single too-casual piece can't hide behind dressier companions.
            // A user per-occasion preference moves the target but never widens
            // the occasion's tolerance.
            let userOccasionPref = context.profile.occasionPreference(for: context.occasion)
            // The user's repeated "too dressy"/"too casual" feedback shifts the
            // target within ±1 level; the occasion's tolerance band is unchanged.
            let formalityTarget = Double(
                (userOccasionPref?.targetFormality ?? context.occasion.targetFormality).rawValue
            ) + tuning.formalityBias
            let formalityTolerance = context.occasion.formalityTolerance
            let core = candidate.filter {
                $0.category.slot != .accessory && $0.category.slot != .outerwear
            }
            let allWithinBand = core.allSatisfy {
                abs(Double($0.formality.rawValue) - formalityTarget) <= formalityTolerance
            }
            if !allWithinBand { continue }

            // Hard filter: Sport requires athletic footwear.
            // Conservative: footwear with no subcategory (untagged) still passes.
            if context.occasion == .sport {
                let hasNonAthleticShoes = candidate.contains {
                    $0.category == .footwear &&
                    $0.footwearSubcategory != nil &&
                    $0.footwearSubcategory != .athletic
                }
                if hasNonAthleticShoes { continue }
            }

            var totalWeight = 0.0
            var weightedScore = 0.0
            var rationale: [String] = []

            func add(weight: Double, result: (score: Double, rationale: String?)) {
                weightedScore += result.score * weight
                totalWeight   += weight
                if let r = result.rationale { rationale.append(r) }
            }

            // Style-axis weights scale by the user's tuning; the appropriateness
            // floors (warmth, formality, recency, rain) are not personalised.
            func styled(_ base: Double, _ axis: StyleAxis) -> Double {
                base * tuning.multiplier(for: axis)
            }
            let relaxed = tuning.prefersRelaxedSilhouette

            add(weight: weights.warmth,    result: warmthResult)
            add(weight: weights.formality, result: scoreFormality(garments: candidate, occasion: context.occasion, profile: context.profile))
            add(weight: styled(weights.color, .color), result: scoreColorHarmony(garments: candidate))
            add(weight: weights.style,     result: scoreStyleMatch(garments: candidate, profile: context.profile, occasion: context.occasion))
            add(weight: weights.recency,   result: scoreRecency(garments: candidate, recentWears: context.recentWears))
            add(weight: weights.rain,      result: scoreRainReadiness(garments: candidate, weather: context.weather))
            add(weight: styled(weights.volume, .volume),       result: scoreVolumeBalance(garments: candidate, prefersRelaxed: relaxed))
            add(weight: styled(weights.structure, .structure), result: scoreStructurePresence(garments: candidate, occasion: context.occasion, prefersRelaxed: relaxed))
            add(weight: styled(weights.pattern, .pattern),     result: scorePatternHarmony(garments: candidate, tolerance: tuning.patternTolerance))
            add(weight: styled(weights.texture, .texture),     result: scoreTextureMix(garments: candidate, weather: context.weather))
            add(weight: styled(weights.archetype, .archetype), result: scoreArchetypeCoherence(garments: candidate))
            add(weight: styled(weights.focal, .focal),         result: scoreFocalPoint(garments: candidate))

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
    /// When `lockedGarmentID` is set, only combinations containing that garment
    /// survive — the "Style this piece" flow, filtered *before* the sampling cap
    /// so the locked item's outfits are never shuffled away.
    private func buildCandidates(from wardrobe: [GarmentSnapshot], lockedGarmentID: UUID? = nil) -> [[GarmentSnapshot]] {
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

        // "Style this piece": keep only outfits that include the locked garment.
        if let lockedGarmentID {
            candidates = candidates.filter { combo in combo.contains { $0.id == lockedGarmentID } }
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
