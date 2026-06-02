//
//  Formality.swift
//  drape
//
//  Domain enum: how dressed-up an item or occasion is.
//

import Foundation

/// Dressiness on an ordered scale. Int-backed so the recommendation engine can
/// measure distance between a garment's formality and an occasion's target.
enum Formality: Int, Codable, CaseIterable, Identifiable, Comparable, Sendable {
    case casual = 0
    case smartCasual = 1
    case business = 2
    case formal = 3

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .casual: "Casual"
        case .smartCasual: "Smart Casual"
        case .business: "Business"
        case .formal: "Formal"
        }
    }

    static func < (lhs: Formality, rhs: Formality) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
