//
//  OccasionPreference.swift
//  drape
//
//  User-defined formality and style preferences for a specific occasion.
//

import Foundation

struct OccasionPreference: Codable, Sendable {
    var occasion: Occasion
    var targetFormality: Formality
    var styles: [StyleTag]
}
