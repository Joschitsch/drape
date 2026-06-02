//
//  Occasion.swift
//  drape
//
//  Domain enum: the context an outfit is for.
//

import Foundation

/// The situation an outfit targets. Each occasion implies a preferred formality
/// range that the recommendation engine scores garments against.
enum Occasion: String, Codable, CaseIterable, Identifiable, Sendable {
    case everyday
    case work
    case date
    case sport
    case formal
    case travel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .everyday: "Everyday"
        case .work: "Work"
        case .date: "Date"
        case .sport: "Sport"
        case .formal: "Formal"
        case .travel: "Travel"
        }
    }

    var systemImage: String {
        switch self {
        case .everyday: "sun.max"
        case .work: "briefcase"
        case .date: "heart"
        case .sport: "figure.run"
        case .formal: "sparkles"
        case .travel: "airplane"
        }
    }

    /// The formality this occasion is centred on; scoring rewards garments near
    /// this and penalises those far from it.
    var targetFormality: Formality {
        switch self {
        case .everyday: .casual
        case .work: .business
        case .date: .smartCasual
        case .sport: .casual
        case .formal: .formal
        case .travel: .casual
        }
    }
}
