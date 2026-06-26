//
//  OutfitStylistRanking.swift
//  drape
//
//  Domain seam for an optional "stylist" pass that re-ranks the rule engine's
//  shortlist for aesthetics — the taste layer the transparent weighted-mean
//  can't capture on its own. Best-effort and non-throwing: returning nil keeps
//  the rules' order, so the feature is strictly additive.
//

import Foundation

/// A compact, text-only description of one candidate outfit for the stylist.
/// Deliberately UI- and model-free so the seam stays `Sendable` and testable.
struct StylistOutfit: Sendable {
    let summary: String
}

/// Re-ranks already-valid, rules-ranked outfits by aesthetic quality. Returns a
/// permutation of the input indices (best → worst), or nil to keep the given
/// order. Never adds, removes, or invents outfits — it only reorders.
protocol OutfitStylistRanking: Sendable {
    func rank(_ outfits: [StylistOutfit]) async -> [Int]?
}

/// No-op stylist: always keeps the rules' order. Used in previews/tests and as
/// the fallback when an on-device model isn't available.
struct PassthroughOutfitStylist: OutfitStylistRanking {
    func rank(_ outfits: [StylistOutfit]) async -> [Int]? { nil }
}
