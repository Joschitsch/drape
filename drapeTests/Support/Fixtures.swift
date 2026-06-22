//
//  Fixtures.swift
//  drapeTests
//
//  Builders for engine inputs so golden tests read as scenarios, not setup.
//

import Foundation
@testable import drape

// MARK: - Garments

func garment(
    _ category: GarmentCategory,
    formality: Formality = .casual,
    warmth: WarmthLevel = .light,
    color: ColorTag = .ink,
    colorHex: String? = nil,
    secondaryColorHexes: [String] = [],
    styles: [String] = [],
    footwearSubcategory: FootwearSubcategory? = nil,
    fit: Fit? = nil,
    topLength: TopLength? = nil,
    bottomVolume: BottomVolume? = nil,
    structure: Structure? = nil,
    fabricWeight: FabricWeight? = nil,
    patternType: PatternType? = nil,
    patternScale: PatternScale? = nil,
    texture: Texture? = nil,
    archetype: Archetype? = nil,
    id: UUID = UUID()
) -> GarmentSnapshot {
    GarmentSnapshot(
        id: id,
        category: category,
        footwearSubcategory: footwearSubcategory,
        primaryColor: color,
        secondaryColors: [],
        primaryColorHex: colorHex,
        secondaryColorHexes: secondaryColorHexes,
        formality: formality,
        warmth: warmth,
        seasons: [],
        styles: styles,
        fit: fit,
        topLength: topLength,
        bottomVolume: bottomVolume,
        structure: structure,
        fabricWeight: fabricWeight,
        patternType: patternType,
        patternScale: patternScale,
        texture: texture,
        archetype: archetype
    )
}

// MARK: - Weather

let hot28 = WeatherSnapshot(temperatureCelsius: 28)
let cold5 = WeatherSnapshot(temperatureCelsius: 5)
let rainy15 = WeatherSnapshot(temperatureCelsius: 15, precipitationChance: 0.9, condition: .rain)

// MARK: - Context

func context(
    wardrobe: [GarmentSnapshot],
    occasion: Occasion,
    weather: WeatherSnapshot? = nil,
    profile: ProfilePreferences = .init(),
    recentWears: [UUID: Date] = [:],
    desiredCount: Int = 5
) -> RecommendationContext {
    RecommendationContext(
        wardrobe: wardrobe,
        occasion: occasion,
        weather: weather,
        profile: profile,
        recentWears: recentWears,
        desiredCount: desiredCount
    )
}

// MARK: - Assertion helpers

/// Resolves a suggestion's garment ids back to snapshots.
func resolve(_ suggestion: OutfitSuggestion, in wardrobe: [GarmentSnapshot]) -> [GarmentSnapshot] {
    suggestion.garmentIDs.compactMap { id in wardrobe.first { $0.id == id } }
}

/// Core garments are the ones the formality floor applies to.
func coreGarments(_ outfit: [GarmentSnapshot]) -> [GarmentSnapshot] {
    outfit.filter { $0.category.slot != .accessory && $0.category.slot != .outerwear }
}

func suggestionsContain(_ suggestions: [OutfitSuggestion], garmentID: UUID) -> Bool {
    suggestions.contains { $0.garmentIDs.contains(garmentID) }
}
