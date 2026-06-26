//
//  StylistRerankingTests.swift
//  drapeTests
//
//  The stylist re-rank decorator reorders the rules' shortlist for taste, but
//  only ever reorders valid candidates — it never invents, drops, or bypasses
//  the base engine's hard filters. A nil result keeps the rules' order.
//

import Foundation
import Testing
@testable import drape

/// Stub stylist returning a fixed order (or nil to pass through).
private struct FixedOrderStylist: OutfitStylistRanking {
    let order: [Int]?
    func rank(_ outfits: [StylistOutfit]) async -> [Int]? { order }
}

@Suite("Stylist re-ranking")
struct StylistRerankingTests {
    private let base = RuleBasedRecommendationEngine()

    /// A wardrobe that yields several distinct valid outfits.
    private var wardrobe: [GarmentSnapshot] {
        [
            garment(.top, color: .navy), garment(.top, color: .rust),
            garment(.bottom, color: .charcoal), garment(.bottom, color: .oat),
            garment(.footwear, color: .ivory), garment(.footwear, color: .ink),
        ]
    }

    @Test("Passthrough (nil) preserves the rules' order")
    func passthroughKeepsOrder() async {
        let engine = StylistRerankingEngine(base: base, stylist: PassthroughOutfitStylist())
        let ctx = context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 3)

        let rules = await base.recommend(ctx)
        let decorated = await engine.recommend(ctx)

        #expect(decorated.map(\.garmentIDs) == rules.map(\.garmentIDs))
    }

    @Test("A stylist order is applied to the surfaced set")
    func stylistOrderApplied() async {
        // Reverse the shortlist; the decorator should lead with what the stylist
        // ranked first.
        let reversed = FixedOrderStylist(order: Array((0..<10).reversed()))
        let engine = StylistRerankingEngine(base: base, stylist: reversed)
        let ctx = context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 3)

        let shortlist = await base.recommend(
            { var c = ctx; c.desiredCount = 10; return c }())
        let decorated = await engine.recommend(ctx)

        #expect(decorated.count == 3)
        // Lead is the stylist's top pick = the last of the rules' shortlist.
        if let expectedLead = shortlist.last, let lead = decorated.first {
            #expect(lead.garmentIDs == expectedLead.garmentIDs)
        }
    }

    @Test("Re-ranking never invents outfits outside the base shortlist")
    func neverInventsOutfits() async {
        // Garbage indices: the decorator must ignore out-of-range ones and still
        // only return outfits the base engine produced.
        let noisy = FixedOrderStylist(order: [99, -1, 2])
        let engine = StylistRerankingEngine(base: base, stylist: noisy)
        let ctx = context(wardrobe: wardrobe, occasion: .everyday, desiredCount: 5)

        let shortlist = await base.recommend(
            { var c = ctx; c.desiredCount = 10; return c }())
        let validIDs = Set(shortlist.map(\.garmentIDs))
        let decorated = await engine.recommend(ctx)

        #expect(!decorated.isEmpty)
        #expect(decorated.allSatisfy { validIDs.contains($0.garmentIDs) })
    }

    @Test("applyOrder is a lossless permutation even when partial")
    func applyOrderIsLossless() {
        let items = ["a", "b", "c", "d"]
        // Only mentions two valid indices (plus an out-of-range one).
        let result = StylistRerankingEngine.applyOrder([2, 9, 0], to: items)
        #expect(result.count == items.count)
        #expect(Set(result) == Set(items))
        #expect(result.prefix(2) == ["c", "a"])   // stylist picks first, in order
    }
}
