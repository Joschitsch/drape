//
//  StyleArchetypeInferring.swift
//  drape
//
//  Domain seam for inferring a garment's style archetype — the one style axis
//  that benefits from semantic reasoning rather than pixel measurement. Runs once
//  at add-time and caches onto the garment; never per recommendation.
//

import Foundation

/// Proposes a single dominant `Archetype` for a garment from lightweight text
/// signal (the classifier's label, category and any user style tags). Best-effort
/// and non-throwing: returns nil when it can't decide, leaving the field unset.
protocol StyleArchetypeInferring: Sendable {
    func inferArchetype(
        descriptor: String?,
        category: GarmentCategory,
        styles: [String]
    ) async -> Archetype?
}

/// Pure, offline fallback: user style tags win, then a small keyword map over the
/// classifier label. Deliberately conservative — returns nil rather than guess.
struct HeuristicStyleArchetypeModel: StyleArchetypeInferring {
    func inferArchetype(
        descriptor: String?,
        category: GarmentCategory,
        styles: [String]
    ) async -> Archetype? {
        // An explicit user tag is the strongest signal.
        for style in styles {
            if let mapped = Archetype.from(style: style) { return mapped }
        }
        guard let d = descriptor?.lowercased() else { return nil }

        if d.contains("hoodie") || d.contains("sweatshirt") || d.contains("track")
            || d.contains("jogger") || d.contains("legging") || d.contains("sneaker")
            || d.contains("trainer") { return .sporty }
        if d.contains("blazer") || d.contains("trench") || d.contains("loafer")
            || d.contains("oxford") || d.contains("dress shirt") || d.contains("button") { return .classic }
        if d.contains("cargo") || d.contains("bomber") || d.contains("puffer")
            || d.contains("parka") || d.contains("graphic") { return .streetwear }
        if d.contains("floral") || d.contains("sundress") || d.contains("maxi")
            || d.contains("kimono") || d.contains("crochet") { return .boho }
        if d.contains("lace") || d.contains("silk") || d.contains("blouse")
            || d.contains("gown") || d.contains("chiffon") { return .romantic }
        if d.contains("leather") || d.contains("biker") || d.contains("moto")
            || d.contains("combat") || d.contains("boot") { return .edgy }
        if d.contains("polo") || d.contains("chino") || d.contains("cardigan")
            || d.contains("knit") || d.contains("sweater") { return .preppy }
        return nil
    }
}
