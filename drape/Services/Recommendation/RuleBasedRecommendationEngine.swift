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

    /// How many garments per slot survive into the cross product, and the overall
    /// candidate ceiling. `topKPerSlot` keeps each slot's strongest pieces (by the
    /// cheap `slotFit` pre-score) so a good outfit is never randomly truncated
    /// before it's scored.
    private static let topKPerSlot = 8
    private static let maxCandidates = 200
    /// MMR trade-off: relevance (score) vs. novelty (dissimilarity to picks).
    /// 1.0 = pure score, 0.0 = pure variety. 0.7 favors quality but breaks up
    /// near-duplicate outfits that differ only by one slot.
    private static let mmrLambda = 0.7

    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion] {
        let candidates = buildCandidates(context: context)
        guard !candidates.isEmpty else { return [] }

        // The user's repeated "too dressy"/"too casual" feedback shifts the
        // target within ±1 level; the occasion's tolerance band is unchanged.
        let formalityTarget = formalityTarget(context: context)
        let formalityTolerance = context.occasion.formalityTolerance

        var scored: [ScoredCandidate] = []

        for candidate in candidates {
            let warmthResult = scoreWarmth(garments: candidate, weather: context.weather)
            // Hard filter: never recommend an outfit that is temperature-wrong.
            if context.weather != nil && warmthResult.score == 0 { continue }

            // Hard filter: every core garment must individually sit within the
            // occasion's formality tolerance of the target — no averaging, so a
            // single too-casual piece can't hide behind dressier companions.
            // A user per-occasion preference moves the target but never widens
            // the occasion's tolerance.
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

            // Score via the shared breakdown so the debug playground and the
            // production ranking can never drift apart.
            let contribs = contributions(for: candidate, context: context)
            let totalWeight = contribs.reduce(0) { $0 + $1.weight }
            let weightedScore = contribs.reduce(0) { $0 + $1.weighted }
            let normalized = totalWeight > 0 ? weightedScore / totalWeight : 0
            scored.append(ScoredCandidate(garments: candidate, score: normalized,
                                          rationale: contribs.compactMap(\.rationale)))
        }

        return selectDiverse(scored, count: context.desiredCount)
            .map { OutfitSuggestion(garmentIDs: $0.garments.map(\.id), score: $0.score, rationale: $0.rationale) }
    }

    /// A scored, still-resolved outfit candidate (garments kept so the diversity
    /// pass can measure overlap before they're flattened to ids).
    private struct ScoredCandidate {
        let garments: [GarmentSnapshot]
        let score: Double
        let rationale: [String]
    }

    /// The effective formality target for the context: the occasion's target (or
    /// the user's per-occasion override) shifted by their clamped feedback bias.
    /// Constant per context, so it's computed once and shared by the candidate
    /// pre-filter and the hard formality floor.
    private func formalityTarget(context: RecommendationContext) -> Double {
        let userOccasionPref = context.profile.occasionPreference(for: context.occasion)
        let base = (userOccasionPref?.targetFormality ?? context.occasion.targetFormality).rawValue
        return Double(base) + context.profile.tuning.formalityBias
    }

    // MARK: - Result diversity (MMR)

    /// Selects up to `count` outfits balancing score against variety. The first
    /// pick is the highest-scored outfit (the relevance anchor, so the lead card
    /// is always "the best"); each subsequent pick maximises Maximal Marginal
    /// Relevance — high score, low similarity to what's already chosen — so the
    /// surfaced set differs by more than a single swapped shoe.
    private func selectDiverse(_ scored: [ScoredCandidate], count: Int) -> [ScoredCandidate] {
        guard count > 0 else { return [] }
        // Deterministic ordering: by score, then a stable id-sequence tie-break.
        var remaining = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return idKey(a.garments) < idKey(b.garments)
        }
        guard !remaining.isEmpty else { return [] }

        var selected: [ScoredCandidate] = [remaining.removeFirst()]
        while selected.count < count && !remaining.isEmpty {
            var bestIndex = 0
            var bestValue = -Double.infinity
            for (i, candidate) in remaining.enumerated() {
                let maxSim = selected.map { similarity(candidate.garments, $0.garments) }.max() ?? 0
                let mmr = Self.mmrLambda * candidate.score - (1 - Self.mmrLambda) * maxSim
                if mmr > bestValue {       // strict > keeps the deterministic order on ties
                    bestValue = mmr
                    bestIndex = i
                }
            }
            selected.append(remaining.remove(at: bestIndex))
        }
        return selected
    }

    /// Jaccard overlap of two outfits' garment ids (0 = no shared pieces, 1 =
    /// identical). Two outfits sharing top + bottom but differing in footwear
    /// land around 0.5, enough for MMR to prefer a genuinely different look.
    private func similarity(_ a: [GarmentSnapshot], _ b: [GarmentSnapshot]) -> Double {
        let aIDs = Set(a.map(\.id))
        let bIDs = Set(b.map(\.id))
        let union = aIDs.union(bIDs).count
        guard union > 0 else { return 0 }
        return Double(aIDs.intersection(bIDs).count) / Double(union)
    }

    /// Stable string key for a garment set, for deterministic tie-breaking.
    private func idKey(_ garments: [GarmentSnapshot]) -> String {
        garments.map(\.id.uuidString).sorted().joined()
    }

    // MARK: - Scoring (single source of truth)

    /// One scorer's contribution to an outfit's score.
    struct ScorerContribution {
        let axis: String
        let raw: Double         // 0…1 from the scorer
        let weight: Double      // base weight × tuning multiplier
        let rationale: String?
        var weighted: Double { raw * weight }
    }

    /// Runs every scorer for one candidate and returns their weighted
    /// contributions. The sole place scorers + weights + tuning are combined, so
    /// both `recommend` and `scoreBreakdown` see identical numbers.
    func contributions(for candidate: [GarmentSnapshot], context: RecommendationContext) -> [ScorerContribution] {
        let tuning = context.profile.tuning
        // Style-axis weights scale by the user's tuning; the appropriateness
        // floors (warmth, formality, recency, rain) are not personalised.
        func styled(_ base: Double, _ axis: StyleAxis) -> Double { base * tuning.multiplier(for: axis) }
        let relaxed = tuning.prefersRelaxedSilhouette

        func c(_ axis: String, _ weight: Double, _ r: (score: Double, rationale: String?)) -> ScorerContribution {
            ScorerContribution(axis: axis, raw: r.score, weight: weight, rationale: r.rationale)
        }

        return [
            c("warmth", weights.warmth, scoreWarmth(garments: candidate, weather: context.weather)),
            c("formality", weights.formality, scoreFormality(garments: candidate, occasion: context.occasion, profile: context.profile)),
            c("color", styled(weights.color, .color), scoreColorHarmony(garments: candidate)),
            c("style", weights.style, scoreStyleMatch(garments: candidate, profile: context.profile, occasion: context.occasion)),
            c("recency", weights.recency, scoreRecency(garments: candidate, recentWears: context.recentWears)),
            c("rain", weights.rain, scoreRainReadiness(garments: candidate, weather: context.weather)),
            c("volume", styled(weights.volume, .volume), scoreVolumeBalance(garments: candidate, prefersRelaxed: relaxed)),
            c("structure", styled(weights.structure, .structure), scoreStructurePresence(garments: candidate, occasion: context.occasion, prefersRelaxed: relaxed)),
            c("pattern", styled(weights.pattern, .pattern), scorePatternHarmony(garments: candidate, tolerance: tuning.patternTolerance)),
            c("texture", styled(weights.texture, .texture), scoreTextureMix(garments: candidate, weather: context.weather)),
            c("archetype", styled(weights.archetype, .archetype), scoreArchetypeCoherence(garments: candidate)),
            c("focal", styled(weights.focal, .focal), scoreFocalPoint(garments: candidate)),
        ]
    }

    // MARK: - Candidate generation

    /// Enumerates valid outfit combinations:
    ///   - (top, bottom, footwear) with optional outerwear
    ///   - (dress, footwear) with optional outerwear
    ///
    /// Each slot is first trimmed to its `topKPerSlot` strongest pieces by the
    /// cheap `slotFit` pre-score, so a good outfit is never randomly dropped
    /// before scoring and the result is fully deterministic (no shuffle). When
    /// `lockedGarmentID` is set, that garment is force-kept in its slot and only
    /// combinations containing it survive — the "Style this piece" flow.
    private func buildCandidates(context: RecommendationContext) -> [[GarmentSnapshot]] {
        let wardrobe = context.wardrobe
        let locked = context.lockedGarmentID
        let target = formalityTarget(context: context)

        // Pre-score every garment once, then trim each slot to its strongest.
        let fitByID = Dictionary(
            wardrobe.map { ($0.id, slotFit($0, context: context, formalityTarget: target)) },
            uniquingKeysWith: { a, _ in a })
        func fit(_ g: GarmentSnapshot) -> Double { fitByID[g.id] ?? 0 }

        func topK(_ category: GarmentCategory) -> [GarmentSnapshot] {
            let items = wardrobe.filter { $0.category == category }
            let ranked = items.sorted { a, b in
                let fa = fit(a), fb = fit(b)
                if fa != fb { return fa > fb }
                return a.id.uuidString < b.id.uuidString   // stable tie-break
            }
            var kept = Array(ranked.prefix(Self.topKPerSlot))
            // A locked garment must survive even if it ranks below the cap.
            if let locked, let item = items.first(where: { $0.id == locked }),
               !kept.contains(where: { $0.id == locked }) {
                kept.append(item)
            }
            return kept
        }

        let tops     = topK(.top)
        let bottoms  = topK(.bottom)
        let dresses  = topK(.dress)
        let footwear = topK(.footwear)

        // Optional layers: nil (no outerwear) plus each kept outerwear item.
        let outerOptions: [GarmentSnapshot?] = [nil] + topK(.outerwear).map { Optional($0) }

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
        if let locked {
            candidates = candidates.filter { combo in combo.contains { $0.id == locked } }
        }

        // Deterministic cap: keep the combinations whose pieces pre-score best,
        // so the ceiling never drops a strong outfit at random.
        if candidates.count > Self.maxCandidates {
            candidates = candidates
                .sorted { a, b in
                    let sa = a.reduce(0) { $0 + fit($1) }
                    let sb = b.reduce(0) { $0 + fit($1) }
                    if sa != sb { return sa > sb }
                    return idKey(a) < idKey(b)   // stable tie-break
                }
                .prefix(Self.maxCandidates)
                .map { $0 }
        }
        return candidates
    }

    /// Cheap per-garment appropriateness for the current context, used to trim
    /// each slot before the cross product. Blends only always-known,
    /// single-garment signals — formality distance to the target, warmth vs.
    /// weather, and recency — so it's a fast pre-filter, not the full ranker.
    private func slotFit(_ g: GarmentSnapshot, context: RecommendationContext, formalityTarget: Double) -> Double {
        // Formality: closeness to the occasion target (0…1).
        let formalityFit = max(0, 1 - abs(Double(g.formality.rawValue) - formalityTarget) / 3.0)

        // Warmth: only layers carry meaningful warmth; footwear/accessories and
        // the no-weather case stay neutral.
        let warmthFit: Double
        if let weather = context.weather,
           g.category.slot != .footwear, g.category.slot != .accessory {
            let temp = weather.apparentTemperatureCelsius
            let lo = g.warmth.comfortableDownToCelsius
            let hi = g.warmth.comfortableUpToCelsius
            if temp >= lo && temp <= hi {
                warmthFit = 1.0
            } else {
                let dist = temp < lo ? lo - temp : temp - hi
                let fade = temp < lo ? 5.0 : 8.0
                warmthFit = max(0, 1 - dist / fade)
            }
        } else {
            warmthFit = 0.5
        }

        // Recency: recently-worn pieces are deprioritised so fresh items make it
        // into the pool. Full credit once a piece is >14 days rested.
        var recencyFit = 1.0
        if let last = context.recentWears[g.id] {
            let days = Date.now.timeIntervalSince(last) / 86_400
            recencyFit = max(0, min(1, days / 14.0))
        }

        return formalityFit * 1.5 + warmthFit * 1.0 + recencyFit * 0.5
    }

    #if DEBUG
    // MARK: - Debug score breakdown (engine playground)

    struct DebugScorerContribution: Sendable {
        let axis: String
        let raw: Double
        let weight: Double
        var weighted: Double { raw * weight }
    }

    struct DebugOutfitScore: Sendable {
        let garmentIDs: [UUID]
        let normalized: Double      // equals the suggestion's `score`
        let contributions: [DebugScorerContribution]
    }

    /// Per-scorer breakdown for each returned suggestion, for the debug playground.
    /// Reuses `contributions(for:context:)`, so `normalized` here equals the
    /// `score` `recommend` produced.
    func scoreBreakdown(_ context: RecommendationContext) async -> [DebugOutfitScore] {
        let suggestions = await recommend(context)
        let byID = Dictionary(context.wardrobe.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return suggestions.map { suggestion in
            let garments = suggestion.garmentIDs.compactMap { byID[$0] }
            let contribs = contributions(for: garments, context: context)
            let totalWeight = contribs.reduce(0) { $0 + $1.weight }
            let weightedScore = contribs.reduce(0) { $0 + $1.weighted }
            return DebugOutfitScore(
                garmentIDs: suggestion.garmentIDs,
                normalized: totalWeight > 0 ? weightedScore / totalWeight : 0,
                contributions: contribs.map {
                    DebugScorerContribution(axis: $0.axis, raw: $0.raw, weight: $0.weight)
                })
        }
    }
    #endif
}
