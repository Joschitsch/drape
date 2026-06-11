//
//  ClassificationSuggestion.swift
//  drape
//
//  Domain value type: a classifier's guess at a garment's attributes.
//

import Foundation

/// What a `GarmentClassifier` proposes for a freshly captured photo. All fields
/// are optional best-guesses the user can confirm or override in the add flow.
struct ClassificationSuggestion: Sendable {
    var category: GarmentCategory?
    var primaryColor: ColorTag?
    var secondaryColors: [ColorTag]
    /// Confidence 0...1 for the category guess, surfaced subtly in the UI.
    var categoryConfidence: Double
    /// Derived from category rules; nil = leave the draft default unchanged.
    var warmth: WarmthLevel?
    var formality: Formality?
    var seasons: Set<Season>?
    var footwearSubcategory: FootwearSubcategory?

    init(
        category: GarmentCategory? = nil,
        primaryColor: ColorTag? = nil,
        secondaryColors: [ColorTag] = [],
        categoryConfidence: Double = 0,
        warmth: WarmthLevel? = nil,
        formality: Formality? = nil,
        seasons: Set<Season>? = nil,
        footwearSubcategory: FootwearSubcategory? = nil
    ) {
        self.category = category
        self.primaryColor = primaryColor
        self.secondaryColors = secondaryColors
        self.categoryConfidence = categoryConfidence
        self.warmth = warmth
        self.formality = formality
        self.seasons = seasons
        self.footwearSubcategory = footwearSubcategory
    }

    static let empty = ClassificationSuggestion()
}
