//
//  DatasetLabelMap.swift
//  drape
//
//  DEBUG-ONLY. Maps raw dataset label strings (e.g. Fashion Product Images
//  `articleType` / `baseColour`, Clothing Dataset class names) onto our enums, so
//  a dataset CSV becomes typed `DebugGroundTruth`. Keyword tables, deliberately
//  permissive — unmapped labels return nil and simply aren't scored.
//

#if DEBUG
import Foundation

enum DatasetLabelMap {
    /// Article-type / class string → `GarmentCategory`. nil when unrecognised.
    nonisolated static func category(forArticleType raw: String) -> GarmentCategory? {
        let l = raw.lowercased()
        // Order matters: check specific/compound terms before generic substrings.
        if l.contains("dress") || l.contains("gown") || l.contains("jumpsuit") || l.contains("romper") { return .dress }
        if l.contains("jacket") || l.contains("coat") || l.contains("blazer") || l.contains("parka")
            || l.contains("outwear") || l.contains("outerwear")
            || l.contains("hoodie sweatshirt") { return .outerwear }
        if l.contains("jean") || l.contains("trouser") || l.contains("pant") || l.contains("short")
            || l.contains("skirt") || l.contains("legging") || l.contains("chino") { return .bottom }
        if l.contains("shoe") || l.contains("sneaker") || l.contains("trainer") || l.contains("boot")
            || l.contains("sandal") || l.contains("heel") || l.contains("loafer") || l.contains("flip") { return .footwear }
        if l.contains("bag") || l.contains("backpack") || l.contains("hat") || l.contains("cap")
            || l.contains("scarf") || l.contains("belt") || l.contains("watch") || l.contains("sunglass")
            || l.contains("glove") || l.contains("tie") { return .accessory }
        if l.contains("shirt") || l.contains("tee") || l.contains("top") || l.contains("blouse")
            || l.contains("sweater") || l.contains("pullover") || l.contains("hoodie")
            || l.contains("cardigan") || l.contains("tank") || l.contains("polo")
            || l.contains("longsleeve") || l.contains("long sleeve") { return .top }
        return nil
    }

    /// Color name (e.g. "Navy Blue", "Off White") → nearest palette `ColorTag`.
    nonisolated static func color(forName raw: String) -> ColorTag? {
        let l = raw.lowercased()
        switch true {
        case l.contains("navy"):                          return .navy
        case l.contains("denim") || l == "blue":          return .denim
        case l.contains("black"):                         return .ink
        case l.contains("charcoal"):                      return .charcoal
        case l.contains("grey"), l.contains("gray"), l.contains("silver"): return .slate
        case l.contains("white"), l.contains("cream"):    return .ivory
        case l.contains("beige"), l.contains("tan"), l.contains("khaki"), l.contains("sand"): return .oat
        case l.contains("camel"), l.contains("mustard"), l.contains("yellow"), l.contains("gold"): return .camel
        case l.contains("brown"), l.contains("coffee"):   return .tobacco
        case l.contains("chocolate"), l.contains("espresso"): return .chocolate
        case l.contains("rust"), l.contains("orange"), l.contains("terracotta"), l.contains("red"): return .rust
        case l.contains("burgundy"), l.contains("maroon"), l.contains("wine"): return .burgundy
        case l.contains("sage"), l.contains("olive"), l.contains("mint"): return .sage
        case l.contains("forest"), l.contains("green"):   return .forest
        case l.contains("mauve"), l.contains("pink"), l.contains("purple"), l.contains("lavender"): return .mauve
        case l.contains("ecru"), l.contains("oat"):       return .ecru
        case l.contains("ivory"):                         return .ivory
        default:                                          return nil
        }
    }

    /// Usage/occasion string (e.g. Fashion Product Images `usage`) → `Formality`.
    nonisolated static func formality(forUsage raw: String) -> Formality? {
        switch raw.lowercased() {
        case "casual", "sports", "smart casual where casual": return .casual
        case "smart casual":                                  return .smartCasual
        case "formal", "ethnic":                              return .formal
        default:                                              return nil
        }
    }

    /// Season string → `Season`. nil when unrecognised.
    nonisolated static func season(forName raw: String) -> Season? {
        switch raw.lowercased() {
        case "spring":          return .spring
        case "summer":          return .summer
        case "fall", "autumn":  return .autumn
        case "winter":          return .winter
        default:                return nil
        }
    }

    /// Builds typed ground truth from one CSV row's raw fields. `rawUsage`/
    /// `rawSeason` come from datasets that carry them (e.g. Fashion Product
    /// Images); when absent those axes stay nil and report coverage-only.
    nonisolated static func groundTruth(
        datasetID: String,
        rawCategory: String?,
        rawColor: String? = nil,
        rawUsage: String? = nil,
        rawSeason: String? = nil
    ) -> DebugGroundTruth {
        DebugGroundTruth(
            datasetID: datasetID,
            rawCategory: rawCategory,
            category: rawCategory.flatMap(category(forArticleType:)),
            color: rawColor.flatMap(color(forName:)),
            season: rawSeason.flatMap(season(forName:)),
            formality: rawUsage.flatMap(formality(forUsage:)))
    }
}
#endif
