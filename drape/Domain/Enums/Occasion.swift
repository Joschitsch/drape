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

    /// Natural phrasing for conversational prompts ("How dressed up for {phrase}?").
    var preferencePhrase: String {
        switch self {
        case .everyday: "everyday"
        case .work: "work"
        case .date: "a date"
        case .sport: "the gym"
        case .formal: "a formal occasion"
        case .travel: "travel"
        }
    }

    var iconName: String {
        switch self {
        case .everyday: "drape.everyday"
        case .work: "drape.work"
        case .date: "drape.date"
        case .sport: "drape.sport"
        case .formal: "drape.formal"
        case .travel: "drape.travel"
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

    /// Maximum allowed formality distance (in raw-value steps) before a candidate
    /// is hard-filtered by the recommendation engine. `.infinity` means no filter.
    ///
    /// Examples with the Formality scale casual(0)…formal(3):
    ///   work(target=2), tolerance=1.5 → accepts casual(0)? |0-2|=2 > 1.5 ✗ filtered
    ///                                  → accepts smartCasual(1)? |1-2|=1 ≤ 1.5 ✓ kept
    ///   formal(target=3), tolerance=1 → accepts business(2)? |2-3|=1 ≤ 1 ✓ kept
    ///                                 → accepts smartCasual(1)? |1-3|=2 > 1 ✗ filtered
    var formalityTolerance: Double {
        switch self {
        case .everyday, .sport, .travel: return .infinity  // relaxed — show everything
        case .date:   return 1.5   // smart-casual ± 1 level
        case .work:   return 1.5   // business ± 1 level
        case .formal: return 1.0   // formal or business only
        }
    }
}
