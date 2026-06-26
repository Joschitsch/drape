//
//  FoundationModelsOutfitStylist.swift
//  drape
//
//  Aesthetic re-ranking via Apple's on-device Foundation Models. Guarded three
//  ways so it's never a hard dependency (compiles without the framework, runs
//  only on OS versions that ship it, degrades when Apple Intelligence is off),
//  and any miss falls back to a passthrough that keeps the rules' order.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsOutfitStylist: OutfitStylistRanking {
    private let fallback: any OutfitStylistRanking

    init(fallback: any OutfitStylistRanking = PassthroughOutfitStylist()) {
        self.fallback = fallback
    }

    func rank(_ outfits: [StylistOutfit]) async -> [Int]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           let order = await modelRank(outfits) {
            return order
        }
        #endif
        return await fallback.rank(outfits)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func modelRank(_ outfits: [StylistOutfit]) async -> [Int]? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }
        guard outfits.count > 1 else { return nil }

        let list = outfits.enumerated()
            .map { "\($0.offset): \($0.element.summary)" }
            .joined(separator: "\n")
        let prompt = """
        Rank these outfits from most to least put-together and stylish, judging
        color harmony, proportion, and overall cohesion.
        Outfits:
        \(list)
        Reply with the outfit numbers in best-to-worst order, comma-separated, and
        nothing else. Example: 2,0,1
        """

        do {
            let session = LanguageModelSession(
                instructions: "You are a concise, tasteful fashion stylist.")
            let response = try await session.respond(to: prompt)
            let order = response.content
                .split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0) }
            return order.isEmpty ? nil : order
        } catch {
            return nil   // fall through to the passthrough
        }
    }
    #endif
}
