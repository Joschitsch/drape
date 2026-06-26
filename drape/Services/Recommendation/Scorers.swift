//
//  Scorers.swift
//  drape
//
//  Composable scoring functions used by RuleBasedRecommendationEngine.
//  Each scorer takes an outfit candidate and context and returns 0...1.
//

import Foundation

// MARK: - Warmth scorer

/// Rewards outfits whose combined warmth matches the apparent temperature.
/// Returns 1 when warmth is a perfect match, 0 when completely wrong season.
func scoreWarmth(garments: [GarmentSnapshot], weather: WeatherSnapshot?) -> (score: Double, rationale: String?) {
    guard let weather else { return (0.5, nil) } // neutral when no weather

    let temp = weather.apparentTemperatureCelsius
    // Warmth is determined by clothing layers only — footwear and accessories
    // don't meaningfully affect how warm an outfit feels.
    let layers = garments.filter { $0.category.slot != .footwear && $0.category.slot != .accessory }
    let maxWarmth = layers.map(\.warmth).max() ?? .medium
    let lo = maxWarmth.comfortableDownToCelsius
    let hi = maxWarmth.comfortableUpToCelsius

    // 1.0 inside the comfort range; asymmetric fade outside it.
    // Underdressing (too cold) fades fast — 5°C window.
    // Overdressing (too warm) fades slowly — 8°C window, since being slightly
    // too warm is far more tolerable than actually being cold.
    let score: Double
    if temp >= lo && temp <= hi {
        score = 1.0
    } else {
        let dist = temp < lo ? lo - temp : temp - hi
        let fadeRange = temp < lo ? 5.0 : 8.0
        score = max(0, 1.0 - dist / fadeRange)
    }

    let rationale: String?
    if score == 0 {
        rationale = temp > hi ? "May be too warm for \(Int(temp))°C" : "May be too light for \(Int(temp))°C"
    } else if score == 1.0 {
        rationale = "Right warmth for \(Int(temp))°C"
    } else {
        rationale = nil
    }
    return (score, rationale)
}

// MARK: - Formality scorer

/// Rewards garments close to the occasion's target formality level.
/// Uses the user's per-occasion preference when available.
func scoreFormality(garments: [GarmentSnapshot], occasion: Occasion, profile: ProfilePreferences) -> (score: Double, rationale: String?) {
    let userPref = profile.occasionPreference(for: occasion)
    let target = userPref?.targetFormality.rawValue ?? occasion.targetFormality.rawValue
    let core = garments.filter { $0.category.slot != .accessory && $0.category.slot != .outerwear }
    guard !core.isEmpty else { return (0.5, nil) }

    let avg = Double(core.map { $0.formality.rawValue }.reduce(0, +)) / Double(core.count)
    let distance = abs(avg - Double(target))
    let score = max(0, 1.0 - (distance / 3.0))

    let rationale: String? = score > 0.8 ? "Fits the \(occasion.displayName.lowercased()) vibe" : nil
    return (score, rationale)
}

// MARK: - Color harmony scorer

/// Grades a palette by real color-theory relationships over drape's fixed
/// swatch hues, not just coarse warm/cool/neutral counts. Neutrals are free
/// anchors; the chromatic "accent" colors carry the look. Rewards tonal/neutral
/// depth, a single accent (or analogous run) on neutrals, and balanced
/// complementary pairs; penalises the awkward middle (hues neither close nor
/// opposite) and three-plus competing hues. Reads `secondaryColors` too — an
/// accent stripe is part of the palette.
func scoreColorHarmony(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
    let colors = garments.flatMap { [$0.primaryColor] + $0.secondaryColors }
    guard !colors.isEmpty else { return (0.5, nil) }

    let accents = colors.filter { $0.family != .neutral }
    let hasNeutralAnchor = colors.contains { $0.family == .neutral }

    // Light/dark depth over the core (non-accessory) pieces.
    let lums = garments.filter { $0.category.slot != .accessory }.map { $0.primaryColor.luminance }
    let depth = (lums.max() ?? 0) - (lums.min() ?? 0)

    func clamp(_ x: Double) -> Double { min(1.0, max(0.0, x)) }

    // All-neutral: the safe classic palette. Reward tonal depth, dock flatness.
    if accents.isEmpty {
        var score = 0.9
        var rationale: String? = "Classic neutral palette"
        if depth > 0.35 { score += 0.08; rationale = "Crisp light-and-dark neutrals" }
        else if depth < 0.08 { score -= 0.05 }
        return (clamp(score), rationale)
    }

    // Cluster accent hues so an analogous run reads as one color story.
    let clusters = clusterHues(accents.compactMap(\.hue), within: 40)

    var score: Double
    var rationale: String?
    switch clusters.count {
    case 0:
        score = 0.85; rationale = "Soft tonal palette"          // muted, near-grey accents
    case 1:
        score = hasNeutralAnchor ? 0.95 : 0.88
        rationale = accents.count == 1 ? "One clean accent on neutrals" : "Harmonious analogous tones"
    case 2:
        if circularGap(clusters[0], clusters[1]) >= 150 {
            // Complementary: graded by how loud the quieter accent is. One
            // dominant color + a muted counterpart reads sophisticated; two
            // strong opposites read busy.
            score = quieterAccentChroma(accents) < 0.18 ? 0.88 : 0.72
            rationale = "Balanced complementary accents"
        } else {
            score = 0.4                                         // awkward middle — clash
        }
    default:
        score = 0.35                                            // three+ competing hues
    }

    if hasNeutralAnchor { score += 0.05 }                       // neutrals harmonise
    if depth > 0.35 { score += 0.05 }                          // pleasing depth
    return (clamp(score), rationale)
}

// MARK: Color-harmony helpers

/// Collapses hue angles into representative clusters: hues within `within`
/// degrees of each other (circularly) count as one color story.
private func clusterHues(_ hues: [Double], within: Double) -> [Double] {
    let sorted = hues.sorted()
    guard !sorted.isEmpty else { return [] }
    var reps: [Double] = []
    for h in sorted {
        if let last = reps.last, circularGap(last, h) <= within { continue }
        reps.append(h)
    }
    // Merge a wraparound cluster (e.g. 350° and 10°).
    if reps.count > 1, circularGap(reps.first!, reps.last!) <= within { reps.removeLast() }
    return reps
}

/// Smallest angular distance between two hues, 0…180°.
private func circularGap(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return min(d, 360 - d)
}

/// Chroma of the loudest accent in a *different* hue cluster from the dominant
/// accent — i.e. how strong the secondary color is. Low means one color clearly
/// leads; high means two colors compete.
private func quieterAccentChroma(_ accents: [ColorTag]) -> Double {
    guard let dominant = accents.max(by: { $0.chroma < $1.chroma }),
          let domHue = dominant.hue else { return 0 }
    return accents
        .filter { ($0.hue.map { circularGap($0, domHue) } ?? 0) > 40 }
        .map(\.chroma)
        .max() ?? 0
}

// MARK: - Style match scorer

/// Rewards outfits whose garment styles overlap with the user's preferred styles.
/// Merges global preferences with any occasion-specific style overrides.
func scoreStyleMatch(garments: [GarmentSnapshot], profile: ProfilePreferences, occasion: Occasion) -> (score: Double, rationale: String?) {
    // Canonicalise both sides so matching is robust to how a style was stored
    // (canonical raw value, legacy built-in, or old custom string).
    let occasionStyles = profile.occasionPreference(for: occasion)?.styles ?? []
    let allPreferred = Set((profile.preferredStyles + occasionStyles).map(Archetype.canonicalStyle))
    guard !allPreferred.isEmpty else { return (0.5, nil) }
    let outfitStyles = Set(garments.flatMap(\.styles).map(Archetype.canonicalStyle))
    guard !outfitStyles.isEmpty else { return (0.3, nil) }

    let overlap = outfitStyles.intersection(allPreferred).count
    let score = min(1.0, Double(overlap) / Double(min(allPreferred.count, outfitStyles.count)))

    let rationale: String? = score > 0.7 ? "Matches your style" : nil
    return (score, rationale)
}

// MARK: - Recency scorer

/// Penalises garments worn very recently to encourage variety.
func scoreRecency(garments: [GarmentSnapshot], recentWears: [UUID: Date]) -> (score: Double, rationale: String?) {
    guard !recentWears.isEmpty else { return (1.0, nil) }

    let now = Date.now
    let totalPenalty = garments.compactMap { recentWears[$0.id] }.map { lastWorn -> Double in
        let daysSince = now.timeIntervalSince(lastWorn) / 86_400
        // Full penalty at 0 days, zero penalty beyond 14 days.
        return max(0, 1.0 - daysSince / 14.0)
    }.reduce(0, +)

    let score = max(0.0, 1.0 - totalPenalty / max(1, Double(garments.count)))
    return (score, nil)
}

// MARK: - Rain scorer

/// Gives a small bonus to outfits with outerwear when it's wet outside.
func scoreRainReadiness(garments: [GarmentSnapshot], weather: WeatherSnapshot?) -> (score: Double, rationale: String?) {
    guard let weather else { return (0.5, nil) }
    let hasOuterwear = garments.contains { $0.category == .outerwear }

    if weather.condition.isWet || weather.precipitationChance > 0.5 {
        return hasOuterwear
            ? (1.0, "Good choice for \(weather.condition == .rain ? "rain" : "wet weather")")
            : (0.2, nil)  // strong penalty — no cover in wet conditions
    }
    return (0.7, nil) // outerwear is neutral when dry
}

// MARK: - Volume balance scorer

/// Rewards proportion: at most one voluminous piece reads as intentional, several
/// at once read as shapeless. A garment is "voluminous" if it's oversized, a long
/// top, or a wide-leg bottom. Neutral (0.5) when no silhouette data is known.
func scoreVolumeBalance(garments: [GarmentSnapshot], prefersRelaxed: Bool = false) -> (score: Double, rationale: String?) {
    func isVoluminous(_ g: GarmentSnapshot) -> Bool {
        if g.fit == .oversized { return true }
        if g.category == .top, g.topLength == .long { return true }
        if g.category == .bottom, g.bottomVolume == .wide { return true }
        return false
    }
    // Only assess when at least one piece carries silhouette signal.
    let hasSignal = garments.contains {
        $0.fit != nil || $0.topLength != nil || $0.bottomVolume != nil
    }
    guard hasSignal else { return (0.5, nil) }

    let voluminous = garments.filter(isVoluminous).count

    // Users who like a relaxed silhouette opted into volume — don't penalise it.
    if prefersRelaxed {
        switch voluminous {
        case 0:  return (0.7, nil)
        case 1, 2: return (1.0, "Relaxed, the way you like it")
        default: return (0.7, nil)
        }
    }

    switch voluminous {
    case 0:  return (0.85, nil)                       // clean lines, perfectly fine
    case 1:  return (1.0, "Balanced proportions")     // one statement volume
    case 2:  return (0.5, nil)
    default: return (0.25, nil)                        // shapeless pile-up
    }
}

// MARK: - Structure presence scorer

/// Outside sport, rewards at least one element with some tailoring and gently
/// penalises a head-to-toe slouchy look. Neutral when structure is unknown or
/// the occasion is sport (where soft, easy pieces are the point).
func scoreStructurePresence(garments: [GarmentSnapshot], occasion: Occasion, prefersRelaxed: Bool = false) -> (score: Double, rationale: String?) {
    guard occasion != .sport else { return (0.5, nil) }
    // Only shaped garments (not footwear/accessories) carry the signal.
    let shaped = garments.filter {
        $0.category.slot != .footwear && $0.category.slot != .accessory
    }
    let known = shaped.compactMap(\.structure)
    guard !known.isEmpty else { return (0.5, nil) }

    if known.contains(where: { $0.isStructured }) {
        return (1.0, nil)                 // a tailored anchor present
    }
    // Everything soft. A relaxed-silhouette user opted into this; others lose a bit.
    return prefersRelaxed ? (0.75, nil) : (0.4, nil)
}

// MARK: - Pattern harmony scorer

/// Prefers one hero pattern carried by solids. Solid-only is safe; two patterns
/// is risky; three or more reads chaotic. Neutral when no pattern data is known.
func scorePatternHarmony(garments: [GarmentSnapshot], tolerance: PatternTolerance = .sometimes) -> (score: Double, rationale: String?) {
    // Count only pieces we actually know the pattern of.
    let known = garments.compactMap(\.isPatterned)
    guard !known.isEmpty else { return (0.5, nil) }

    let patterned = known.filter { $0 }.count

    switch tolerance {
    case .avoid:
        // The user wants solids — every added pattern costs.
        switch patterned {
        case 0:  return (1.0, "Clean, solid palette")
        case 1:  return (0.55, nil)
        case 2:  return (0.3, nil)
        default: return (0.1, nil)
        }
    case .love:
        // Pattern mixing is welcome; only true overload pulls back.
        switch patterned {
        case 0:  return (0.7, nil)
        case 1:  return (1.0, "One pattern, kept simple")
        case 2:  return (0.9, "Patterns mixed with intent")
        default: return (0.6, nil)
        }
    case .sometimes:
        switch patterned {
        case 0:
            return (0.8, nil)                           // all solids — clean
        case 1:
            return (1.0, "One pattern, kept simple")    // hero + solids
        case 2:
            // A deliberate two-pattern mix can work when the scales differ and the
            // palettes are compatible (shared family, or anchored by neutrals).
            let patternedPieces = garments.filter { $0.isPatterned == true }
            let scales = Set(patternedPieces.compactMap(\.patternScale))
            let families = Set(patternedPieces.map { $0.primaryColor.family })
            let compatiblePalette = families.count == 1 || families.contains(.neutral)
            if scales.count >= 2 && compatiblePalette {
                return (0.7, "Patterns mixed with intent")
            }
            return (0.4, nil)
        default:
            return (0.2, nil)                           // pattern clash
        }
    }
}

// MARK: - Focal point scorer

/// Favors outfits with one clear "hero" piece and quieter supporting cast over
/// three or four items all competing for attention. Loudness blends color
/// saturation, pattern and texture, so this is the single rule that makes those
/// axes cooperate instead of each penalising busyness on its own.
func scoreFocalPoint(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
    // Accessories are allowed to be loud (that's their job); judge the rest.
    let pieces = garments.filter { $0.category.slot != .accessory }
    guard pieces.count >= 2 else { return (0.5, nil) }

    let loudCount = pieces.filter { $0.visualLoudness > 0.55 }.count
    switch loudCount {
    case 0:  return (0.7, nil)                                  // all quiet — safe, a touch flat
    case 1:  return (1.0, "One piece leads, the rest support")
    case 2:  return (0.5, nil)
    default: return (0.3, nil)                                  // everything shouting
    }
}

// MARK: - Texture mix scorer

/// Rewards one rich texture carried by smoother pieces; penalises a pile of heavy
/// textures — except in real cold, where chunky knits and heavy weaves are the
/// point. Neutral when texture is unknown.
func scoreTextureMix(garments: [GarmentSnapshot], weather: WeatherSnapshot?) -> (score: Double, rationale: String?) {
    let shaped = garments.filter {
        $0.category.slot != .footwear && $0.category.slot != .accessory
    }
    let known = shaped.compactMap(\.texture)
    guard !known.isEmpty else { return (0.5, nil) }

    let heavy = known.filter(\.isHeavyTexture).count
    let veryCold = (weather?.apparentTemperatureCelsius ?? 99) < 6

    switch heavy {
    case 0:  return (0.8, nil)                        // all smooth/subtle — clean
    case 1:  return (1.0, "One rich texture")         // hero texture + support
    default: return veryCold ? (0.8, nil) : (0.4, nil) // texture overload (unless cold)
    }
}

// MARK: - Archetype coherence scorer

/// Computes a simple outfit-level style vector and rewards cohesion. Soft by
/// design: it lifts consistent looks toward 1.0 but never pushes a mixed look
/// below neutral, so intentional contrast isn't punished. Phase 4 makes the
/// cohesion-vs-contrast preference user-tunable.
func scoreArchetypeCoherence(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
    let voteSets = garments.map(\.archetypeVotes).filter { !$0.isEmpty }
    guard voteSets.count >= 2 else { return (0.5, nil) }

    var tally: [Archetype: Int] = [:]
    for set in voteSets { for archetype in set { tally[archetype, default: 0] += 1 } }
    guard let dominant = tally.max(by: { $0.value < $1.value })?.key else { return (0.5, nil) }

    let agreeing = voteSets.filter { $0.contains(dominant) }.count
    let cohesion = Double(agreeing) / Double(voteSets.count)
    let score = 0.5 + 0.5 * cohesion   // 0.5 (split) … 1.0 (fully aligned)

    let rationale: String? = cohesion >= 0.8 ? "A clear \(dominant.displayName.lowercased()) look" : nil
    return (score, rationale)
}
