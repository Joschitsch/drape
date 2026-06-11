//
//  GarmentFilter.swift
//  drape
//

import Foundation

/// Secondary attribute constraints for the wardrobe grid. Category and Favorites
/// are handled by the always-visible chip row; this covers everything else.
/// Semantics: AND across attributes, OR within one attribute.
struct GarmentFilter: Equatable {
    var colors:      Set<ColorTag>    = []
    var formalities: Set<Formality>   = []
    var warmths:     Set<WarmthLevel> = []
    var seasons:     Set<Season>      = []
    var styles:      Set<String>      = []

    var isActive: Bool {
        !colors.isEmpty || !formalities.isEmpty || !warmths.isEmpty
            || !seasons.isEmpty || !styles.isEmpty
    }

    func matches(_ g: Garment) -> Bool {
        if !colors.isEmpty,      !colors.contains(g.primaryColor)       { return false }
        if !formalities.isEmpty, !formalities.contains(g.formality)     { return false }
        if !warmths.isEmpty,     !warmths.contains(g.warmth)            { return false }
        if !seasons.isEmpty,     seasons.isDisjoint(with: g.seasons)    { return false }
        if !styles.isEmpty,      styles.isDisjoint(with: g.styles)      { return false }
        return true
    }

    mutating func clear() { self = GarmentFilter() }

    mutating func prune(to facets: GarmentFacets) {
        colors.formIntersection(facets.colors)
        formalities.formIntersection(facets.formalities)
        warmths.formIntersection(facets.warmths)
        seasons.formIntersection(facets.seasons)
        styles.formIntersection(facets.styles)
    }
}

/// Distinct secondary attribute values actually present in a garment list.
/// Used to populate filter sections with only non-empty options.
struct GarmentFacets: Equatable {
    let colors:      [ColorTag]
    let formalities: [Formality]
    let warmths:     [WarmthLevel]
    let seasons:     [Season]
    let styles:      [String]

    init(_ garments: [Garment]) {
        colors      = ColorTag.allCases.filter    { v in garments.contains { $0.primaryColor == v } }
        formalities = Formality.allCases.filter   { v in garments.contains { $0.formality == v } }
        warmths     = WarmthLevel.allCases.filter { v in garments.contains { $0.warmth == v } }
        seasons     = Season.allCases.filter      { v in garments.contains { $0.seasons.contains(v) } }
        styles      = Set(garments.flatMap(\.styles)).sorted()
    }
}
