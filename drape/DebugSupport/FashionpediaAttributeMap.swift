//
//  FashionpediaAttributeMap.swift
//  drape
//
//  DEBUG-ONLY. Maps Fashionpedia's CC-BY ontology (27 categories, 294
//  fine-grained attributes across 9 supercategories) onto the *existing* Drape
//  enums, so its annotations become ground truth for the harness. Pure keyword
//  matching over attribute names — robust to the exact supercategory strings.
//  Only the axes that map cleanly are covered (pattern, bottom volume, top
//  length, best-effort texture); sleeve/neckline/etc. have no Drape enum.
//

#if DEBUG
import Foundation

enum FashionpediaAttributeMap {
    /// Fashionpedia category name → `GarmentCategory`. Reuses the dataset keyword
    /// map and supplements the few Fashionpedia-specific names it doesn't cover.
    nonisolated static func category(forName raw: String) -> GarmentCategory? {
        let l = raw.lowercased()
        // Fashionpedia-specific structural items first — some collide with dataset
        // keywords (e.g. "cape" contains "cap" → would mis-map to accessory).
        if l.contains("vest") { return .top }
        if l.contains("cape") || l.contains("poncho") { return .outerwear }
        if l.contains("tight") || l.contains("stocking") || l.contains("legging") { return .bottom }
        if let mapped = DatasetLabelMap.category(forArticleType: raw) { return mapped }
        if l.contains("sock") || l.contains("glove") || l.contains("umbrella")
            || l.contains("tie") || l.contains("scarf") { return .accessory }
        return nil
    }

    /// Textile-pattern attribute names → `PatternType`. nil when no pattern axis
    /// is annotated (so it isn't scored), `.solid` when explicitly plain.
    nonisolated static func patternType(from names: [String]) -> PatternType? {
        let l = names.map { $0.lowercased() }
        func any(_ keys: String...) -> Bool { l.contains { n in keys.contains { n.contains($0) } } }
        if any("floral", "flower") { return .floral }
        if any("stripe", "pinstripe") { return .stripe }
        if any("check", "plaid", "tartan", "gingham", "houndstooth", "windowpane", "argyle") { return .check }
        if any("graphic", "letters", "numbers", "logo", "cartoon", "text", "print") { return .graphic }
        if any("paisley", "geometric", "abstract", "animal", "leopard", "camouflage", "camo", "polka", "dot", "tie-dye", "tie dye") { return .abstract }
        if any("plain", "no pattern", "solid") { return .solid }
        return nil
    }

    /// Garment-silhouette attribute names → `BottomVolume` (for bottoms).
    nonisolated static func bottomVolume(from names: [String]) -> BottomVolume? {
        let l = names.map { $0.lowercased() }
        func any(_ keys: String...) -> Bool { l.contains { n in keys.contains { n.contains($0) } } }
        if any("skinny", "pencil", "slim", "tapered") { return .slim }
        if any("wide", "flare", "flared", "bootcut", "boot cut", "balloon", "baggy",
               "a-line", "a line", "circle", "palazzo", "loose", "oversized") { return .wide }
        if any("straight", "regular") { return .straight }
        return nil
    }

    /// Garment-length attribute names → `TopLength` (for tops/dresses).
    nonisolated static func topLength(from names: [String]) -> TopLength? {
        let l = names.map { $0.lowercased() }
        func any(_ keys: String...) -> Bool { l.contains { n in keys.contains { n.contains($0) } } }
        if any("crop", "micro", "mini", "above-the-hip") { return .cropped }
        if any("maxi", "floor", "ankle", "knee", "midi", "calf", "longline", "long", "below-the-hip") { return .long }
        if any("regular", "hip", "waist", "normal") { return .regular }
        return nil
    }

    /// Best-effort texture from finishing/material names. Conservative — returns
    /// nil unless a name clearly implies a smooth or busy surface.
    nonisolated static func texture(from names: [String]) -> Texture? {
        let l = names.map { $0.lowercased() }
        func any(_ keys: String...) -> Bool { l.contains { n in keys.contains { n.contains($0) } } }
        if any("knit", "cable", "tweed", "corduroy", "terry", "lace", "mesh",
               "eyelet", "crochet", "quilted", "ribbed", "velvet", "sequin") { return .textured }
        if any("leather", "satin", "silk", "smooth", "patent", "jersey") { return .smooth }
        return nil
    }
}
#endif
