//
//  Season.swift
//  drape
//
//  Domain enum: seasons a garment is appropriate for.
//

import Foundation

/// Seasons a garment suits. Stored as a list on `Garment` (an item can span
/// several). String-backed for stable persistence.
enum Season: String, Codable, CaseIterable, Identifiable, Sendable {
    case spring
    case summer
    case autumn
    case winter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spring: "Spring"
        case .summer: "Summer"
        case .autumn: "Autumn"
        case .winter: "Winter"
        }
    }
}
