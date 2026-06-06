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
    enum Phase { case idle, loading, results, error(String) }

    var phase: Phase = .idle
    var occasion: Occasion = .everyday
    /// Resolved suggestions, with their garment models for display.
    var suggestions: [(suggestion: OutfitSuggestion, garments: [Garment])] = []
    var weatherSummary: String?
    /// Last successfully fetched weather snapshot — used by WeatherStrip.
    var lastWeather: WeatherSnapshot?

    func refresh(
        wardrobe: [Garment],
        profile: UserProfile?,
        container: AppContainer
    ) async {
        phase = .loading
        suggestions = []
        weatherSummary = nil

        // Fetch location + weather concurrently; weather falls back to nil if
        // either service fails (recommendations still run without weather).
        let weather = await fetchWeather(container: container)
        if let w = weather {
            weatherSummary = "\(w.condition.systemImage)  \(Int(w.apparentTemperatureCelsius))°C"
            lastWeather = w
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
            preferredColors: profile?.preferredColors ?? [],
            defaultFormality: profile?.defaultFormality ?? .smartCasual,
            occasionPreferences: profile?.occasionPreferences ?? []
        )
        let context = RecommendationContext(
            wardrobe: wardrobe.filter { !$0.isArchived }.map(\.snapshot),
            occasion: occasion,
            weather: weather,
            season: .current(),
            profile: prefs,
            recentWears: recentWears,
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

        phase = .results
    }

    // MARK: - Helpers

    private func fetchWeather(container: AppContainer) async -> WeatherSnapshot? {
        do {
            let coord = try await container.location.currentCoordinate()
            return try await container.weather.currentWeather(at: coord)
        } catch {
            return nil
        }
    }
}
