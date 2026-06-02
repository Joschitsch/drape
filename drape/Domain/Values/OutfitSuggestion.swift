//
//  OutfitSuggestion.swift
//  drape
//
//  Domain value type: one scored outfit proposal from the engine.
//

import Foundation

/// A proposed outfit produced by the recommendation engine. References garments
/// by id (resolved back to `Garment` models for display) and carries a score
/// plus a human-readable rationale so the UI can explain *why* it was suggested.
struct OutfitSuggestion: Identifiable, Sendable {
    var id: UUID = UUID()
    /// Garment ids per slot. A `fullBody` (dress) entry replaces top+bottom.
    var garmentIDs: [UUID]
    /// Overall score, 0...1, used for ranking.
    var score: Double
    /// Short reasons shown to the user, e.g. "Warm enough for 8°C", "Matches your minimal style".
    var rationale: [String]

    init(garmentIDs: [UUID], score: Double, rationale: [String] = []) {
        self.garmentIDs = garmentIDs
        self.score = score
        self.rationale = rationale
    }
}
