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

    init(
        category: GarmentCategory? = nil,
        primaryColor: ColorTag? = nil,
        secondaryColors: [ColorTag] = [],
        categoryConfidence: Double = 0
    ) {
        self.category = category
        self.primaryColor = primaryColor
        self.secondaryColors = secondaryColors
        self.categoryConfidence = categoryConfidence
    }

    static let empty = ClassificationSuggestion()
}
