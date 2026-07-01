//
//  RecommendationsViewModel.swift
//  drape
//
//  Assembles a RecommendationContext from live data and runs the engine.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class RecommendationsViewModel {
    /// Why a run came back with no suggestions. The engine returns the same
    /// empty array for "can't assemble an outfit at all" and "assembled plenty,
    /// but the occasion/weather hard filters rejected every one" — the empty
    /// state needs to say different things for each.
    enum EmptyReason: Equatable {
        /// Wardrobe can't form any outfit: missing footwear, or no
        /// top + bottom pair and no dress.
        case missingSlots
        /// Outfits were possible, but every candidate fell outside the
        /// occasion's formality band or the weather's warmth requirement.
        case nothingSuitsContext
    }

    var occasion: Occasion = .everyday {
        didSet {
            UserDefaults.standard.set(occasion.rawValue, forKey: "drape.lastOccasion")
        }
    }
    /// Resolved suggestions, with their garment models for display.
    var suggestions: [(suggestion: OutfitSuggestion, garments: [Garment])] = []

    init() {
        if let raw = UserDefaults.standard.string(forKey: "drape.lastOccasion"),
           let saved = Occasion(rawValue: raw) {
            occasion = saved
        }
    }
    /// Set when the last `refresh` produced no suggestions; nil otherwise.
    var emptyReason: EmptyReason?
    var weatherSummary: String?
    /// Last successfully fetched weather snapshot — used by WeatherStrip.
    var lastWeather: WeatherSnapshot?
    /// True while the first-appearance weather fetch is in flight — drives the
    /// weather skeleton so the strip doesn't pop in.
    var isLoadingWeather = false
    /// Reverse-geocoded current location name — shown in WeatherStrip.
    var locationName: String?
    /// A location the user chose to plan for instead of where they are. nil means
    /// "use my current location". Session-only — never persisted, so the tab
    /// resets to live location on relaunch.
    var plannedPlace: PlaceSuggestion?

    /// Name of the location the picks are responding to: the planned override if
    /// set, otherwise the reverse-geocoded current location.
    var activeLocationName: String? { plannedPlace?.name ?? locationName }

    /// Eagerly loads weather + location name (no engine run) so the weather
    /// widget is populated as soon as the Style tab appears. Cheap to call;
    /// no-ops the heavy work, only fetching when we don't already have weather.
    func loadWeather(container: AppContainer) async {
        guard lastWeather == nil else { return }
        isLoadingWeather = true
        defer { isLoadingWeather = false }
        lastWeather = await fetchWeather(container: container)
    }

    /// Switches the location the tab plans for. Pass a place to plan for it, or
    /// nil to revert to the current location. Re-fetches weather for the new
    /// coordinate; the caller re-runs the engine if looks are already showing.
    func selectPlace(_ place: PlaceSuggestion?, container: AppContainer) async {
        plannedPlace = place
        lastWeather = nil
        isLoadingWeather = true
        defer { isLoadingWeather = false }
        lastWeather = await fetchWeather(container: container)
    }

    /// The coordinate the tab is planning against: the planned override if set,
    /// otherwise the device's current location.
    private func activeCoordinate(container: AppContainer) async throws -> Coordinate {
        if let plannedPlace { return plannedPlace.coordinate }
        return try await container.location.currentCoordinate()
    }

    func refresh(
        wardrobe: [Garment],
        profile: UserProfile?,
        container: AppContainer
    ) async {
        // Don't clear `suggestions` up front: the prior set stays visible (dimmed
        // by the view while generating) and is replaced atomically below once the
        // new results resolve, so switching occasion crossfades instead of flashing
        // the empty state mid-load.

        // Reuse the weather cached by `loadWeather` — the recommendation engine
        // runs in-memory, so blocking it on a fresh network round-trip is what
        // made loading drag. Only fetch synchronously if we have nothing yet;
        // otherwise refresh in the background for staleness.
        let weather: WeatherSnapshot?
        if let cached = lastWeather {
            weather = cached
            refreshWeatherInBackground(container: container)
        } else {
            weather = await fetchWeather(container: container)
            lastWeather = weather
        }
        if let w = weather {
            weatherSummary = "\(w.condition.displayName) · \(Int(w.apparentTemperatureCelsius))°C"
        }

        // Build wear history: garmentID → most recent WearEvent date.
        let recentWears: [UUID: Date] = Dictionary(
            wardrobe.flatMap { g in
                g.wearEvents.compactMap { e -> (UUID, Date)? in
                    guard e.date > Date.now.addingTimeInterval(-14 * 86_400) else { return nil }
                    return (g.id, e.date)
                }
            },
            uniquingKeysWith: { max($0, $1) }
        )

        let prefs = ProfilePreferences(
            preferredStyles: profile?.preferredStyles ?? [],
            occasionPreferences: profile?.occasionPreferences ?? [],
            tuning: profile?.styleTuning ?? StyleTuning()
        )
        let context = RecommendationContext(
            wardrobe: wardrobe.filter { !$0.isArchived }.map(\.snapshot),
            occasion: occasion,
            weather: weather,
            profile: prefs,
            recentWears: recentWears,
            // The curated set the Style tab shows (swipe through up to 5).
            desiredCount: 5
        )

        let engine = container.recommendationEngine
        let raw = await engine.recommend(context)

        // Resolve garment IDs back to SwiftData models for the UI.
        let lookup = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id, $0) })
        suggestions = raw.map { suggestion in
            let garments = suggestion.garmentIDs.compactMap { lookup[$0] }
            return (suggestion, garments)
        }
        emptyReason = suggestions.isEmpty ? Self.emptyReason(for: context.wardrobe) : nil
    }

    /// Records a thumbs rating: nudges the user's persistent style tuning and logs
    /// an `OutfitFeedback` row. Future runs read the updated tuning automatically.
    func submitFeedback(
        positive: Bool,
        reasons: [FeedbackReason],
        suggestion: OutfitSuggestion,
        profile: UserProfile?,
        context: ModelContext
    ) {
        guard let profile else { return }
        profile.applyFeedback(reasons: reasons, positive: positive)
        context.insert(OutfitFeedback(
            positive: positive,
            reasons: reasons,
            garmentIDs: suggestion.garmentIDs,
            occasion: occasion))
        try? context.save()
    }

    /// Diagnoses why a run over `wardrobe` produced nothing. Mirrors the
    /// engine's candidate shapes (top + bottom + footwear, or dress + footwear):
    /// if neither shape can be assembled the wardrobe is the problem; otherwise
    /// the hard filters rejected everything.
    nonisolated static func emptyReason(for wardrobe: [GarmentSnapshot]) -> EmptyReason {
        let categories = Set(wardrobe.map(\.category))
        let canAssemble = categories.contains(.footwear)
            && ((categories.contains(.top) && categories.contains(.bottom))
                || categories.contains(.dress))
        return canAssemble ? .nothingSuitsContext : .missingSlots
    }

    // MARK: - Helpers

    /// Fire-and-forget weather refresh used when we already have a cached value:
    /// keeps the strip current without blocking the recommendation run.
    private func refreshWeatherInBackground(container: AppContainer) {
        Task { [weak self] in
            guard let self else { return }
            if let fresh = await self.fetchWeather(container: container) {
                self.lastWeather = fresh
            }
        }
    }

    private func fetchWeather(container: AppContainer) async -> WeatherSnapshot? {
        do {
            let coord = try await activeCoordinate(container: container)
            // When planning for a chosen place, its name is already known; only
            // reverse-geocode for the live current location.
            if plannedPlace == nil {
                async let name = container.location.placeName(for: coord)
                let weather = try await container.weather.currentWeather(at: coord)
                locationName = await name
                return weather
            }
            return try await container.weather.currentWeather(at: coord)
        } catch {
            return nil
        }
    }
}
