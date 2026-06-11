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
    var formality: Formality = .casual
    var warmth: WarmthLevel = .medium
    var seasons: Set<Season> = []
    var styles: Set<String> = []
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
        formality = garment.formality
        warmth = garment.warmth
        seasons = Set(garment.seasons)
        styles = Set(garment.styles)
        brand = garment.brand ?? ""
        notes = garment.notes ?? ""
        isFavorite = garment.isFavorite
    }

    /// Writes the draft back onto a garment and bumps `updatedAt`.
    func apply(to garment: Garment) {
        garment.name = name.trimmed.isEmpty ? nil : name.trimmed
        garment.category = category
        garment.subcategory = footwearSubcategory?.rawValue
        garment.primaryColor = primaryColor
        garment.customColorHex = customColorHex
        garment.secondaryColors = secondaryColors
        garment.formality = formality
        garment.warmth = warmth
        garment.seasons = Season.allCases.filter { seasons.contains($0) }
        garment.styles = styles.sorted()
        garment.brand = brand.trimmed.isEmpty ? nil : brand.trimmed
        garment.notes = notes.trimmed.isEmpty ? nil : notes.trimmed
        garment.isFavorite = isFavorite
        garment.updatedAt = .now
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
