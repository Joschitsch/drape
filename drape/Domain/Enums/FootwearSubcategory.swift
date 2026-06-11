//
//  FootwearSubcategory.swift
//  drape
//

import Foundation

/// Coarse footwear type used to enforce occasion-appropriate shoe choices.
/// Stored as a raw string in `Garment.subcategory` so no SwiftData migration
/// is needed. Only applies to `GarmentCategory.footwear`.
enum FootwearSubcategory: String, CaseIterable, Codable, Identifiable, Sendable {
    var id: String { rawValue }
    case athletic
    case sandal
    case loafer
    case dress
    case boot

    var displayName: String {
        switch self {
        case .athletic: "Athletic"
        case .sandal:   "Sandal"
        case .loafer:   "Loafer"
        case .dress:    "Dress"
        case .boot:     "Boot"
        }
    }
}
