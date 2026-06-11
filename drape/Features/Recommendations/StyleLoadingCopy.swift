//
//  StyleLoadingCopy.swift
//  drape
//
//  The Style tab's loading line — what the typewriter types while picks are
//  assembled. Adapts to the chosen occasion and, when known, the user's city.
//  Dry and funny, never cringe. The `{city}` token is filled in (or its line
//  dropped) so a missing location never leaves a hole in the sentence.
//

import Foundation

enum StyleLoadingCopy {
    /// A single loading line tuned to `occasion` and, when available, `city`.
    static func line(for occasion: Occasion, city: String?) -> String {
        let pool = templates(for: occasion)
        // Keep city lines only when we actually have a city.
        let usable = pool.filter { city != nil || !$0.contains("{city}") }
        let chosen = (usable.isEmpty ? pool : usable).randomElement() ?? pool[0]
        return chosen.replacingOccurrences(of: "{city}", with: city ?? "")
    }

    private static func templates(for occasion: Occasion) -> [String] {
        switch occasion {
        case .everyday:
            [
                "Assembling something for another day of being perceived…",
                "Finding clothes that quietly say you've got it together…",
                "Curating your “I left the house on purpose” look…",
                "Dressing you for whatever {city} throws at you today…",
                "Rummaging for the comfortable-but-not-giving-up option…",
            ]
        case .work:
            [
                "Engineering maximum competence, minimum effort…",
                "Assembling an outfit that emails “I have read your message”…",
                "Locating the blazer energy this meeting demands…",
                "Dressing you to look employable in {city}…",
                "Finding clothes that mean business, lightly…",
            ]
        case .date:
            [
                "Building an outfit that says “catch”, casually…",
                "Finding something that survives dinner and second thoughts…",
                "Curating effortless — rehearsed twelve times…",
                "Dressing you to be the best-looking person in {city} tonight…",
                "Picking pieces worth a lingering second glance…",
            ]
        case .sport:
            [
                "Finding clothes that believe in you more than you do…",
                "Assembling gear ready to sweat on your behalf…",
                "Curating peak “I might actually go” aesthetics…",
                "Dressing you to outrun {city}'s weather…",
                "Pulling pieces for your body's big day out…",
            ]
        case .formal:
            [
                "Summoning your inner person-who-owns-a-blazer…",
                "Dressing you for a room with cloth napkins…",
                "Curating quiet, expensive-looking calm…",
                "Finding something worthy of {city}'s finest…",
                "Locating the outfit your most elegant self approves…",
            ]
        case .travel:
            [
                "Finding layers for three climates and one plane…",
                "Dressing you to look good in every time zone…",
                "Curating “effortless traveler”, batteries not included…",
                "Packing your body for {city}…",
                "Assembling an outfit that survives the carry-on life…",
            ]
        }
    }
}
