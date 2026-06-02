//
//  MockWeatherService.swift
//  drape
//
//  Weather stub for previews, tests and offline use.
//

import Foundation

/// Returns a fixed (configurable) `WeatherSnapshot`. Used in previews/tests and
/// as a fallback when the real Open-Meteo service is unavailable. The live
/// implementation (`OpenMeteoWeatherService`) arrives in the recommendations step.
struct MockWeatherService: WeatherService {
    var snapshot: WeatherSnapshot

    init(snapshot: WeatherSnapshot = WeatherSnapshot(
        temperatureCelsius: 14,
        precipitationChance: 0.1,
        condition: .cloudy
    )) {
        self.snapshot = snapshot
    }

    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        snapshot
    }
}
