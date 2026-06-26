//
//  StylistRerankingEngine.swift
//  drape
//
//  A RecommendationEngine decorator: it lets the base rules engine produce a
//  varied, hard-filtered shortlist, then asks an OutfitStylistRanking to reorder
//  it for taste before returning the top picks. The stylist can only reorder
//  valid candidates — it can never bypass the warmth/formality/sport hard
//  filters or invent outfits — so this stays strictly additive.
//

import Foundation

struct StylistRerankingEngine: RecommendationEngine {
    let base: any RecommendationEngine
    let stylist: any OutfitStylistRanking
    /// How many candidates to hand the stylist. Larger than the display count so
    /// a genuinely better-looking outfit just outside the top few can still win.
    var shortlistSize: Int = 10

    func recommend(_ context: RecommendationContext) async -> [OutfitSuggestion] {
        // Ask the base for a larger, already-diverse shortlist.
        var enlarged = context
        enlarged.desiredCount = max(context.desiredCount, shortlistSize)
        let shortlist = await base.recommend(enlarged)
        guard shortlist.count > 1 else {
            return Array(shortlist.prefix(context.desiredCount))
        }

        let byID = Dictionary(context.wardrobe.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let outfits = shortlist.map { StylistOutfit(summary: Self.summary($0, byID: byID)) }

        guard let order = await stylist.rank(outfits) else {
            return Array(shortlist.prefix(context.desiredCount))  // keep rules' order
        }

        let reordered = Self.applyOrder(order, to: shortlist)
        return Array(reordered.prefix(context.desiredCount))
    }

    /// Applies a (possibly partial or noisy) index permutation: takes the valid,
    /// in-range, de-duplicated indices the stylist returned, then appends any
    /// outfits it left out — so the result is always a full, lossless reordering.
    static func applyOrder<T>(_ order: [Int], to items: [T]) -> [T] {
        var seen = Set<Int>()
        var result: [T] = []
        for i in order where items.indices.contains(i) && seen.insert(i).inserted {
            result.append(items[i])
        }
        for i in items.indices where !seen.contains(i) {
            result.append(items[i])
        }
        return result
    }

    /// One-line, text-only description of an outfit for the stylist prompt.
    private static func summary(_ suggestion: OutfitSuggestion,
                                byID: [UUID: GarmentSnapshot]) -> String {
        suggestion.garmentIDs.compactMap { id -> String? in
            guard let g = byID[id] else { return nil }
            var parts = [g.primaryColor.displayName.lowercased(), g.category.displayName.lowercased()]
            if g.isPatterned == true, let p = g.patternType, p != .solid {
                parts.insert(p.rawValue, at: 1)
            }
            return parts.joined(separator: " ")
        }
        .joined(separator: ", ")
    }
}
