//
//  DebugWardrobe.swift
//  drape
//
//  DEBUG-ONLY. Named subsets of imported garments ("classic office", "streetwear",
//  "mixed") selected by predicate over their *inferred* attributes, so one import
//  serves many test wardrobes. Selection is deterministic.
//

#if DEBUG
import Foundation

enum DebugWardrobe: String, CaseIterable, Identifiable, Sendable {
    case classicOffice
    case streetwear
    case mixed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classicOffice: "Classic office"
        case .streetwear:    "Streetwear"
        case .mixed:         "Mixed"
        }
    }

    /// Whether a garment belongs in this wardrobe, judged on inferred attributes.
    func matches(_ s: GarmentSnapshot) -> Bool {
        switch self {
        case .classicOffice:
            if s.formality.rawValue >= Formality.business.rawValue { return true }
            return !s.archetypeVotes.isDisjoint(with: [.classic, .preppy])
        case .streetwear:
            return !s.archetypeVotes.isDisjoint(with: [.streetwear, .sporty, .edgy])
        case .mixed:
            return true
        }
    }

    /// Deterministically selects matching records. `mixed` is a stable, evenly
    /// strided sample (no RNG) capped at `limit`; the themed wardrobes take every
    /// match. Input is assumed already in deterministic import order.
    func select(from records: [DebugImportRecord], limit: Int = 60) -> [DebugImportRecord] {
        let matched = records.filter { matches($0.inferred) }
        guard self == .mixed, matched.count > limit else { return matched }
        let stride = Double(matched.count) / Double(limit)
        return (0..<limit).map { matched[Int(Double($0) * stride)] }
    }
}
#endif
