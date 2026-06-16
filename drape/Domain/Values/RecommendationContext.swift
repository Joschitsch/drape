//
//  RecommendationContext.swift
//  drape
//
//  Domain value type: everything the recommendation engine needs as input.
//

import Foundation

/// The complete, self-contained input to a `RecommendationEngine`. Bundling it
/// into one value keeps the engine protocol simple and makes it trivial to test
/// with fixed inputs.
struct RecommendationContext: Sendable {
    /// Candidate garments to build outfits from (already filtered to non-archived).
    var wardrobe: [GarmentSnapshot]
    var occasion: Occasion
    var weather: WeatherSnapshot?
    var profile: ProfilePreferences
    /// Recently worn garment ids → most recent wear date, for recency penalties.
    var recentWears: [UUID: Date]
    /// How many outfit suggestions to return.
    var desiredCount: Int

    init(
        wardrobe: [GarmentSnapshot],
        occasion: Occasion,
        weather: WeatherSnapshot? = nil,
        profile: ProfilePreferences = .init(),
        recentWears: [UUID: Date] = [:],
        desiredCount: Int = 5
    ) {
        self.wardrobe = wardrobe
        self.occasion = occasion
        self.weather = weather
        self.profile = profile
        self.recentWears = recentWears
        self.desiredCount = desiredCount
    }
}

/// An immutable, `Sendable` snapshot of a `Garment`'s recommendation-relevant
/// fields. Decouples the engine from SwiftData reference types so it can run off
/// the main actor and be unit-tested without a `ModelContext`.
struct GarmentSnapshot: Identifiable, Hashable, Sendable {
    var id: UUID
    var category: GarmentCategory
    /// Populated for `.footwear`; nil for all other categories and for footwear
    /// that has not yet been tagged.
    var footwearSubcategory: FootwearSubcategory?
    var primaryColor: ColorTag
    var secondaryColors: [ColorTag]
    var formality: Formality
    var warmth: WarmthLevel
    var seasons: [Season]
    var styles: [String]

    // Silhouette / fabric / pattern axes. Optional: nil means the attribute is
    // unknown and scorers should treat it as neutral, never as a penalty.
    var fit: Fit?
    var topLength: TopLength?
    var bottomVolume: BottomVolume?
    var structure: Structure?
    var fabricWeight: FabricWeight?
    var patternType: PatternType?
    var patternScale: PatternScale?
    var texture: Texture?
    var archetype: Archetype?

    init(
        id: UUID,
        category: GarmentCategory,
        footwearSubcategory: FootwearSubcategory? = nil,
        primaryColor: ColorTag,
        secondaryColors: [ColorTag] = [],
        formality: Formality,
        warmth: WarmthLevel,
        seasons: [Season] = [],
        styles: [String] = [],
        fit: Fit? = nil,
        topLength: TopLength? = nil,
        bottomVolume: BottomVolume? = nil,
        structure: Structure? = nil,
        fabricWeight: FabricWeight? = nil,
        patternType: PatternType? = nil,
        patternScale: PatternScale? = nil,
        texture: Texture? = nil,
        archetype: Archetype? = nil
    ) {
        self.id = id
        self.category = category
        self.footwearSubcategory = footwearSubcategory
        self.primaryColor = primaryColor
        self.secondaryColors = secondaryColors
        self.formality = formality
        self.warmth = warmth
        self.seasons = seasons
        self.styles = styles
        self.fit = fit
        self.topLength = topLength
        self.bottomVolume = bottomVolume
        self.structure = structure
        self.fabricWeight = fabricWeight
        self.patternType = patternType
        self.patternScale = patternScale
        self.texture = texture
        self.archetype = archetype
    }

    /// The garment's archetype signal: the explicit archetype when set, otherwise
    /// whatever its free-form `styles` map onto. Empty when nothing is known — so
    /// the coherence scorer can stay neutral rather than guess.
    var archetypeVotes: Set<Archetype> {
        if let archetype { return [archetype] }
        return Set(styles.compactMap(Archetype.from(style:)))
    }

    /// Whether the surface reads as patterned. `nil` when neither pattern field is
    /// known, so callers can keep "unknown" distinct from "solid".
    var isPatterned: Bool? {
        if let patternType { return patternType != .solid }
        if let patternScale { return patternScale != .none }
        return nil
    }

    /// How much the piece "shouts" — a 0…1 blend of color saturation, pattern and
    /// texture. Used by the focal-point scorer to favor one hero + quiet support.
    /// Always computable (color is always known); pattern/texture only add.
    var visualLoudness: Double {
        // Color chroma tops out around 0.45 in the palette; map it to 0…0.5.
        var loud = min(1.0, primaryColor.chroma / 0.45) * 0.5
        if isPatterned == true {
            switch patternScale {
            case .large:  loud += 0.4
            case .medium: loud += 0.3
            case .small:  loud += 0.25
            default:      loud += 0.3   // patterned, scale unknown
            }
        }
        if texture == .textured { loud += 0.15 }
        return min(1.0, loud)
    }
}

/// The subset of `UserProfile` the engine reads.
struct ProfilePreferences: Sendable {
    var preferredStyles: [String]
    var occasionPreferences: [OccasionPreference]

    init(
        preferredStyles: [String] = [],
        occasionPreferences: [OccasionPreference] = []
    ) {
        self.preferredStyles = preferredStyles
        self.occasionPreferences = occasionPreferences
    }

    func occasionPreference(for occasion: Occasion) -> OccasionPreference? {
        occasionPreferences.first { $0.occasion == occasion }
    }
}

extension Garment {
    /// Projects this model into a `Sendable` snapshot for the engine.
    var snapshot: GarmentSnapshot {
        GarmentSnapshot(
            id: id,
            category: category,
            footwearSubcategory: subcategory.flatMap { FootwearSubcategory(rawValue: $0) },
            primaryColor: primaryColor,
            secondaryColors: secondaryColors,
            formality: formality,
            warmth: warmth,
            seasons: seasons,
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
}
