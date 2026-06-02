//
//  OpenMeteoWeatherService.swift
//  drape
//
//  Free, no-API-key weather from open-meteo.com. See the project cost constraint.
//

import Foundation

/// Fetches current conditions from the Open-Meteo public API and maps them to
/// a `WeatherSnapshot`. No API key or account needed.
struct OpenMeteoWeatherService: WeatherService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func currentWeather(at coordinate: Coordinate) async throws -> WeatherSnapshot {
        let url = try buildURL(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherServiceError.requestFailed
        }
        return try decode(data)
    }

    // MARK: - URL

    private func buildURL(latitude: Double, longitude: Double) throws -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude",                value: String(latitude)),
            .init(name: "longitude",               value: String(longitude)),
            .init(name: "current",                 value: "temperature_2m,apparent_temperature,precipitation_probability,weather_code"),
            .init(name: "forecast_days",           value: "1"),
        ]
        guard let url = components.url else { throw WeatherServiceError.requestFailed }
        return url
    }

    // MARK: - Decoding

    private func decode(_ data: Data) throws -> WeatherSnapshot {
        let root = try JSONDecoder().decode(OpenMeteoRoot.self, from: data)
        let current = root.current
        return WeatherSnapshot(
            temperatureCelsius: current.temperature2m,
            apparentTemperatureCelsius: current.apparentTemperature,
            precipitationChance: Double(current.precipitationProbability) / 100.0,
            condition: WeatherCondition(wmoCode: current.weatherCode)
        )
    }
}

// MARK: - Response types

private struct OpenMeteoRoot: Decodable {
    let current: CurrentWeather
}

private struct CurrentWeather: Decodable {
    let temperature2m: Double
    let apparentTemperature: Double
    let precipitationProbability: Int
    let weatherCode: Int

    enum CodingKeys: String, CodingKey {
        case temperature2m           = "temperature_2m"
        case apparentTemperature     = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case weatherCode             = "weather_code"
    }
}

// MARK: - WMO code mapping

private extension WeatherCondition {
    /// Maps WMO weather interpretation codes to our coarse condition buckets.
    /// https://open-meteo.com/en/docs#weathervariables
    init(wmoCode: Int) {
        switch wmoCode {
        case 0, 1:          self = .clear
        case 2, 3:          self = .cloudy
        case 51...67:       self = .rain
        case 71...77:       self = .snow
        case 80...82:       self = .rain
        case 85, 86:        self = .snow
        case 95...99:       self = .storm
        default:            self = .cloudy
        }
    }
}
