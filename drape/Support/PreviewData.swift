//
//  PreviewData.swift
//  drape
//
//  Sample data for SwiftUI previews and first-launch demo content. The sample
//  wardrobe mirrors the design prototype's lookbook so the editorial language
//  is visible immediately (real capture replaces it as the user adds pieces).
//

import Foundation
import SwiftData

enum PreviewData {

    /// One sample garment + its wear history.
    private struct Spec {
        let name: String
        let category: GarmentCategory
        let color: ColorTag
        let sub: String
        let formality: Formality
        let warmth: WarmthLevel
        let seasons: [Season]
        let styles: [StyleTag]
        let brand: String
        let lastWornDays: Int?
        let favorite: Bool
        let wearCount: Int
        let notes: String?
    }

    private static let specs: [Spec] = [
        Spec(name: "Ivory oversized shirt", category: .top, color: .ivory, sub: "Shirt",
             formality: .smartCasual, warmth: .light, seasons: [.spring, .summer, .autumn],
             styles: [.minimal, .classic], brand: "COS", lastWornDays: 3, favorite: true,
             wearCount: 24, notes: "Goes with everything. The reliable one."),
        Spec(name: "Charcoal merino crew", category: .top, color: .charcoal, sub: "Knit",
             formality: .smartCasual, warmth: .warm, seasons: [.autumn, .winter],
             styles: [.classic], brand: "Uniqlo", lastWornDays: 6, favorite: false,
             wearCount: 31, notes: nil),
        Spec(name: "Oat fisherman knit", category: .top, color: .oat, sub: "Knit",
             formality: .smartCasual, warmth: .veryWarm, seasons: [.winter],
             styles: [.classic], brand: "Jamieson's", lastWornDays: 88, favorite: true,
             wearCount: 5, notes: "Smells like winter."),
        Spec(name: "Indigo selvedge denim", category: .bottom, color: .denim, sub: "Jeans",
             formality: .casual, warmth: .medium, seasons: [.spring, .autumn, .winter],
             styles: [.streetwear], brand: "A.P.C.", lastWornDays: 2, favorite: true,
             wearCount: 52, notes: "Breaking in nicely."),
        Spec(name: "Ecru pleated trousers", category: .bottom, color: .ecru, sub: "Trousers",
             formality: .business, warmth: .medium, seasons: [.spring, .summer, .autumn],
             styles: [.classic, .elegant], brand: "COS", lastWornDays: 4, favorite: true,
             wearCount: 19, notes: nil),
        Spec(name: "White leather sneakers", category: .footwear, color: .ivory, sub: "Sneakers",
             formality: .smartCasual, warmth: .medium, seasons: Season.allCases,
             styles: [.minimal, .sporty], brand: "Common Projects", lastWornDays: 1, favorite: true,
             wearCount: 64, notes: nil),
        Spec(name: "Brown suede loafers", category: .footwear, color: .tobacco, sub: "Loafers",
             formality: .business, warmth: .medium, seasons: [.spring, .autumn],
             styles: [.classic], brand: "Loake", lastWornDays: 22, favorite: false,
             wearCount: 16, notes: nil),
        Spec(name: "Navy chore jacket", category: .outerwear, color: .navy, sub: "Jacket",
             formality: .smartCasual, warmth: .medium, seasons: [.spring, .autumn],
             styles: [.classic], brand: "Vetra", lastWornDays: 11, favorite: false,
             wearCount: 22, notes: nil),
        Spec(name: "Camel wool overcoat", category: .outerwear, color: .camel, sub: "Coat",
             formality: .formal, warmth: .veryWarm, seasons: [.winter],
             styles: [.elegant], brand: "Sandro", lastWornDays: 132, favorite: true,
             wearCount: 7, notes: "The investment piece. Always feels like an event."),
        Spec(name: "Burgundy silk scarf", category: .accessory, color: .burgundy, sub: "Scarf",
             formality: .business, warmth: .light, seasons: [.autumn, .winter],
             styles: [.classic], brand: "Drake's", lastWornDays: 64, favorite: false,
             wearCount: 4, notes: nil),
    ]

    private static func makeGarment(_ s: Spec) -> Garment {
        let g = Garment(category: s.category, primaryColor: s.color, name: s.name,
                        formality: s.formality, warmth: s.warmth, seasons: s.seasons,
                        styles: s.styles, brand: s.brand, notes: s.notes)
        g.subcategory = s.sub
        g.isFavorite = s.favorite
        // Back-date creation so "added N days ago" analytics read realistically.
        g.createdAt = Calendar.current.date(byAdding: .day, value: -((s.lastWornDays ?? 30) + 30), to: .now) ?? .now
        return g
    }

    /// Plain sample garments (no wear history) for previews that don't need a context.
    @MainActor
    static func sampleGarments() -> [Garment] { specs.map(makeGarment) }

    /// Ensures a `UserProfile` exists and, on the very first launch, seeds the
    /// demo wardrobe so the app opens into a populated lookbook.
    @MainActor
    static func ensureProfile(into context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        seed(into: context)
    }

    /// Inserts a profile, the sample wardrobe (with wear history) and a few
    /// outfits. Used on first launch and by preview/test containers.
    @MainActor
    static func seed(into context: ModelContext) {
        let profile = UserProfile(
            preferredStyles: [.minimal, .classic, .elegant],
            preferredColors: [.ecru, .charcoal, .camel, .navy],
            defaultFormality: .smartCasual,
            hasCompletedOnboarding: true
        )
        // Berlin — drives weather + the "{city} · now" weather strip.
        profile.homeLatitude = 52.52
        profile.homeLongitude = 13.405
        context.insert(profile)

        // Garments + their wear events.
        var byName: [String: Garment] = [:]
        for s in specs {
            let g = makeGarment(s)
            context.insert(g)
            byName[s.name] = g
            guard let last = s.lastWornDays else { continue }
            let events = min(s.wearCount, 8)
            for i in 0..<events {
                // Most recent event at `last` days ago, spreading the rest back in time.
                let daysAgo = last + i * 9
                let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
                context.insert(WearEvent(date: date, garments: [g]))
            }
        }

        // A couple of saved outfits in head-to-toe order.
        func outfit(_ name: String, _ names: [String], _ occasion: Occasion, _ tags: [String], wears: Int) {
            let gs = names.compactMap { byName[$0] }
            guard gs.count >= 2 else { return }
            let o = Outfit(name: name, garments: gs, occasion: occasion, tags: tags)
            context.insert(o)
            for i in 0..<wears {
                let date = Calendar.current.date(byAdding: .day, value: -(5 + i * 14), to: .now) ?? .now
                context.insert(WearEvent(date: date, outfit: o, garments: gs))
            }
        }
        outfit("Sunday slow morning", ["Ivory oversized shirt", "Indigo selvedge denim", "White leather sneakers"],
               .everyday, ["easy", "weekend"], wears: 8)
        outfit("The good meeting", ["Camel wool overcoat", "Charcoal merino crew", "Brown suede loafers"],
               .work, ["sharp", "cold"], wears: 3)
        outfit("Wine bar, late", ["Oat fisherman knit", "Ecru pleated trousers", "Burgundy silk scarf"],
               .date, ["warm", "evening"], wears: 1)

        try? context.save()
    }
}
