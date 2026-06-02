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
    // Combine warmth by taking the maximum slot warmth (outerwear dominates).
    let maxWarmth = garments.map(\.warmth).max() ?? .medium
    let comfortable = maxWarmth.comfortableUpToCelsius

    // Score peaks when temp is in the comfortable range for this warmth level.
    let lower = comfortable - 8  // comfortable from (lower..comfortable]
    let score: Double
    if temp > comfortable + 5 {
        score = 0.1   // outfit is too warm
    } else if temp < lower - 10 {
        score = 0.1   // outfit is too light
    } else if temp <= comfortable && temp >= lower {
        score = 1.0   // sweet spot
    } else {
        // Linear fade outside the sweet spot.
        let distAbove = max(0, temp - comfortable)
        let distBelow = max(0, lower - temp)
        score = max(0, 1.0 - (max(distAbove, distBelow) / 10.0))
    }

    let rationale: String?
    if score < 0.3 {
        rationale = temp > comfortable ? "May be too warm for \(Int(temp))°C" : "May be too light for \(Int(temp))°C"
    } else if score > 0.8 {
        rationale = "Right warmth for \(Int(temp))°C"
    } else {
        rationale = nil
    }
    return (score, rationale)
}

// MARK: - Formality scorer

/// Rewards garments close to the occasion's target formality level.
func scoreFormality(garments: [GarmentSnapshot], occasion: Occasion) -> (score: Double, rationale: String?) {
    let target = occasion.targetFormality.rawValue
    // Use the average formality of core slots (dress/top/bottom); accessories
    // don't contribute to the formality score.
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
func scoreStyleMatch(garments: [GarmentSnapshot], profile: ProfilePreferences) -> (score: Double, rationale: String?) {
    guard !profile.preferredStyles.isEmpty else { return (0.5, nil) }
    let outfitStyles = Set(garments.flatMap(\.styles))
    guard !outfitStyles.isEmpty else { return (0.3, nil) }

    let preferred = Set(profile.preferredStyles)
    let overlap = outfitStyles.intersection(preferred).count
    let score = min(1.0, Double(overlap) / Double(min(preferred.count, outfitStyles.count)))

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

// MARK: - Season scorer

/// Rewards items tagged for the current season; neutral otherwise.
func scoreSeason(garments: [GarmentSnapshot], season: Season) -> (score: Double, rationale: String?) {
    let tagged = garments.filter { !$0.seasons.isEmpty }
    guard !tagged.isEmpty else { return (0.5, nil) }

    let inSeason = tagged.filter { $0.seasons.contains(season) }.count
    let score = Double(inSeason) / Double(tagged.count)
    let rationale: String? = score == 1.0 ? "In season" : nil
    return (score, rationale)
}

// MARK: - Rain scorer

/// Gives a small bonus to outfits with outerwear when it's wet outside.
func scoreRainReadiness(garments: [GarmentSnapshot], weather: WeatherSnapshot?) -> (score: Double, rationale: String?) {
    guard let weather else { return (0.5, nil) }
    let hasOuterwear = garments.contains { $0.category == .outerwear }

    if weather.condition.isWet || weather.precipitationChance > 0.5 {
        return hasOuterwear
            ? (1.0, "Good choice for \(weather.condition == .rain ? "rain" : "wet weather")")
            : (0.6, nil)
    }
    return (0.7, nil) // outerwear is neutral when dry
}
