//
//  GarmentDraft.swift
//  drape
//
//  Mutable, value-type editing buffer shared by the add and edit flows so both
//  drive the same attribute form.
//

import Foundation

/// Editable representation of a garment's attributes. The add flow starts from a
/// blank/classified draft; the edit flow loads one from an existing `Garment`
/// and writes it back on save. Using a value type keeps the form free of
/// SwiftData side effects until the user commits.
struct GarmentDraft {
    var name: String = ""
    var category: GarmentCategory = .top
    var footwearSubcategory: FootwearSubcategory? = nil
    var primaryColor: ColorTag = .ink
    var customColorHex: String? = nil
    var secondaryColors: [ColorTag] = []
    var secondaryColorHexes: [String] = []
    var formality: Formality = .casual
    var warmth: WarmthLevel = .medium
    var seasons: Set<Season> = []
    var styles: Set<String> = []
    // Silhouette / fabric / pattern — pre-filled by the classifier, all optional
    // so an unset chip means "not specified" rather than a forced default.
    var fit: Fit? = nil
    var topLength: TopLength? = nil
    var bottomVolume: BottomVolume? = nil
    var structure: Structure? = nil
    var fabricWeight: FabricWeight? = nil
    var patternType: PatternType? = nil
    var patternScale: PatternScale? = nil
    var texture: Texture? = nil
    var archetype: Archetype? = nil
    var brand: String = ""
    var notes: String = ""
    var isFavorite: Bool = false

    init() {}

    /// Loads attributes from an existing garment for editing.
    init(from garment: Garment) {
        name = garment.name ?? ""
        category = garment.category
        footwearSubcategory = garment.subcategory.flatMap { FootwearSubcategory(rawValue: $0) }
        primaryColor = garment.primaryColor
        customColorHex = garment.customColorHex
        secondaryColors = garment.secondaryColors
        secondaryColorHexes = garment.secondaryColorHexes
        formality = garment.formality
        warmth = garment.warmth
        seasons = Set(garment.seasons)
        styles = Set(garment.styles)
        fit = garment.fit
        topLength = garment.topLength
        bottomVolume = garment.bottomVolume
        structure = garment.structure
        fabricWeight = garment.fabricWeight
        patternType = garment.patternType
        patternScale = garment.patternScale
        texture = garment.texture
        archetype = garment.archetype
        brand = garment.brand ?? ""
        notes = garment.notes ?? ""
        isFavorite = garment.isFavorite
    }

    /// Pre-fills the draft from a classifier suggestion, overwriting only the
    /// axes the classifier actually committed to (nil = leave as-is). Shared by
    /// the add flow and the debug bulk importer so both interpret a
    /// `ClassificationSuggestion` identically. Does not touch `name` (auto-named
    /// separately) and only applies `archetype` if the suggestion carries one.
    mutating func apply(classification s: ClassificationSuggestion) {
        if let color = s.primaryColor          { primaryColor = color }
        // The extracted hex is the true color; the tag above is its display label.
        if let hex = s.primaryColorHex         { customColorHex = hex }
        if !s.secondaryColorHexes.isEmpty {
            secondaryColorHexes = s.secondaryColorHexes
            // Keep the snapped tags in step for any UI/debug reads.
            secondaryColors = s.secondaryColorHexes.map {
                let c = PerceptualColor(hex: $0)
                return ColorTag.nearest(red: c.red, green: c.green, blue: c.blue)
            }
        }
        if let category = s.category           { self.category = category }
        if let warmth = s.warmth               { self.warmth = warmth }
        if let formality = s.formality         { self.formality = formality }
        if let seasons = s.seasons             { self.seasons = seasons }
        if let sub = s.footwearSubcategory     { footwearSubcategory = sub }
        if let fit = s.fit                     { self.fit = fit }
        if let topLength = s.topLength         { self.topLength = topLength }
        if let bottomVolume = s.bottomVolume   { self.bottomVolume = bottomVolume }
        if let structure = s.structure         { self.structure = structure }
        if let fabricWeight = s.fabricWeight   { self.fabricWeight = fabricWeight }
        if let patternType = s.patternType     { self.patternType = patternType }
        if let patternScale = s.patternScale   { self.patternScale = patternScale }
        if let texture = s.texture             { self.texture = texture }
        if let archetype = s.archetype         { self.archetype = archetype }
    }

    /// Writes the draft back onto a garment and bumps `updatedAt`.
    func apply(to garment: Garment) {
        garment.name = name.trimmed.isEmpty ? nil : name.trimmed
        garment.category = category
        garment.subcategory = footwearSubcategory?.rawValue
        garment.primaryColor = primaryColor
        garment.customColorHex = customColorHex
        garment.secondaryColors = secondaryColors
        garment.secondaryColorHexes = secondaryColorHexes
        garment.formality = formality
        garment.warmth = warmth
        garment.seasons = Season.allCases.filter { seasons.contains($0) }
        garment.styles = styles.sorted()
        garment.fit = fit
        garment.topLength = topLength
        garment.bottomVolume = bottomVolume
        garment.structure = structure
        garment.fabricWeight = fabricWeight
        garment.patternType = patternType
        garment.patternScale = patternScale
        garment.texture = texture
        garment.archetype = archetype
        garment.brand = brand.trimmed.isEmpty ? nil : brand.trimmed
        garment.notes = notes.trimmed.isEmpty ? nil : notes.trimmed
        garment.isFavorite = isFavorite
        garment.updatedAt = .now
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
