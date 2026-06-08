//
//  WeatherSnapshot.swift
//  drape
//
//  Domain value type: a point-in-time weather reading.
//

import Foundation

/// A provider-agnostic snapshot of current conditions. Concrete `WeatherService`
/// implementations (Open-Meteo, a mock) map their responses into this so the
/// rest of the app never depends on a particular weather API.
struct WeatherSnapshot: Equatable, Sendable {
    var temperatureCelsius: Double
    /// "Feels like" if the provider supplies it, else equal to `temperatureCelsius`.
    var apparentTemperatureCelsius: Double
    var precipitationChance: Double   // 0...1
    var condition: WeatherCondition
    var timestamp: Date

    init(
        temperatureCelsius: Double,
        apparentTemperatureCelsius: Double? = nil,
        precipitationChance: Double = 0,
        condition: WeatherCondition = .clear,
        timestamp: Date = .now
    ) {
        self.temperatureCelsius = temperatureCelsius
        self.apparentTemperatureCelsius = apparentTemperatureCelsius ?? temperatureCelsius
        self.precipitationChance = precipitationChance
        self.condition = condition
        self.timestamp = timestamp
    }
}

/// Coarse condition buckets, enough for outfit logic (e.g. suggest outerwear
/// when rainy). Maps from provider-specific weather codes.
enum WeatherCondition: String, Codable, CaseIterable, Sendable {
    case clear
    case cloudy
    case rain
    case snow
    case storm

    var iconName: String {
        switch self {
        case .clear: "drape.weather.clear"
        case .cloudy: "drape.weather.cloudy"
        case .rain: "drape.weather.rain"
        case .snow: "drape.weather.snow"
        case .storm: "drape.weather.storm"
        }
    }

    var isWet: Bool { self == .rain || self == .snow || self == .storm }
}
