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

    /// The season for a given date in the northern hemisphere. Used to bias
    /// suggestions toward seasonally appropriate items.
    static func current(for date: Date = .now, calendar: Calendar = .current) -> Season {
        switch calendar.component(.month, from: date) {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
    }
}
