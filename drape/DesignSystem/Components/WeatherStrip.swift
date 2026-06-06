//
//  WeatherStrip.swift
//  drape
//
//  Compact weather card used by the Style tab's occasion-picker screen.
//

import SwiftUI

struct WeatherStrip: View {
    let weather: WeatherSnapshot
    /// Home city, shown in the "{city} · now" kicker when known.
    var city: String? = nil

    var body: some View {
        HStack(alignment: .center) {
            // ── Left: location + condition ───────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                MonoLabel(city.map { "\($0) · now" } ?? "Now")
                SerifText(weather.condition.displayName, size: 22)
            }

            Spacer()

            // ── Right: temperature ───────────────────────────────────
            VStack(alignment: .trailing, spacing: 5) {
                SerifText("\(Int(weather.temperatureCelsius))°", size: 34)
                MonoLabel("Feels \(Int(weather.apparentTemperatureCelsius))° · \(Int(weather.precipitationChance * 100))% rain", size: 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}

extension WeatherCondition {
    var displayName: String {
        switch self {
        case .clear:  "Clear"
        case .cloudy: "Cloudy"
        case .rain:   "Rainy"
        case .snow:   "Snow"
        case .storm:  "Stormy"
        }
    }
}

#Preview {
    WeatherStrip(weather: WeatherSnapshot(
        temperatureCelsius: 13,
        apparentTemperatureCelsius: 11,
        precipitationChance: 0.6,
        condition: .rain
    ))
    .padding()
}
