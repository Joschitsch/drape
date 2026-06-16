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

/// Rewards outfits where colors are harmonious: all neutrals, or one accent +
/// neutrals, or monochromatic warm/cool groupings.
func scoreColorHarmony(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
    let colors = garments.map(\.primaryColor)
    let families = Set(colors.map(\.family))

    let score: Double
    let rationale: String?
    if families == [.neutral] {
        // All neutral = always safe
        score = 1.0
        rationale = "Classic neutral palette"
    } else if families.count == 1 {
        // Monochromatic (all warm or all cool)
        score = 0.85
        rationale = nil
    } else if families.count == 2 && families.contains(.neutral) {
        // One accent family + neutrals = great combo
        score = 0.9
        rationale = nil
    } else {
        // Mixed warm + cool without neutrals anchoring = harder to pull off
        score = 0.5
        rationale = nil
    }
    return (score, rationale)
}

// MARK: - Style match scorer

/// Rewards outfits whose garment styles overlap with the user's preferred styles.
/// Merges global preferences with any occasion-specific style overrides.
func scoreStyleMatch(garments: [GarmentSnapshot], profile: ProfilePreferences, occasion: Occasion) -> (score: Double, rationale: String?) {
    let occasionStyles = profile.occasionPreference(for: occasion)?.styles ?? []
    let allPreferred = Set(profile.preferredStyles + occasionStyles)
    guard !allPreferred.isEmpty else { return (0.5, nil) }
    let outfitStyles = Set(garments.flatMap(\.styles))
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
func scoreVolumeBalance(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
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
func scoreStructurePresence(garments: [GarmentSnapshot], occasion: Occasion) -> (score: Double, rationale: String?) {
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
    return (0.4, nil)                     // everything soft — a touch shapeless
}

// MARK: - Pattern harmony scorer

/// Prefers one hero pattern carried by solids. Solid-only is safe; two patterns
/// is risky; three or more reads chaotic. Neutral when no pattern data is known.
func scorePatternHarmony(garments: [GarmentSnapshot]) -> (score: Double, rationale: String?) {
    // Count only pieces we actually know the pattern of.
    let known = garments.compactMap(\.isPatterned)
    guard !known.isEmpty else { return (0.5, nil) }

    let patterned = known.filter { $0 }.count
    switch patterned {
    case 0:  return (0.8, nil)                          // all solids — clean
    case 1:  return (1.0, "One pattern, kept simple")   // hero + solids
    case 2:  return (0.45, nil)
    default: return (0.2, nil)                           // pattern clash
    }
}
