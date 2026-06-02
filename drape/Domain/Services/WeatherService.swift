//
//  WeatherService.swift
//  drape
//
//  Domain protocol: fetch current weather for a location.
//

import Foundation

/// Fetches current conditions for a coordinate and maps them to a
/// `WeatherSnapshot`. The MVP implementation calls Open-Meteo (free, no API
/// key, no account); a `MockWeatherService` backs previews/tests and offline use.
protocol WeatherService: Sendable {
    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot
}

enum WeatherServiceError: Error {
    case requestFailed
    case decodingFailed
    case unavailable
}
