//
//  WeatherStrip.swift
//  drape
//
//  Compact weather card used by the Style tab's occasion-picker screen.
//

import SwiftUI

struct WeatherStrip: View {
    let weather: WeatherSnapshot

    var body: some View {
        HStack(alignment: .center) {
            // ── Left: condition ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                Label("Current location", systemImage: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
                HStack(spacing: 6) {
                    Image(systemName: weather.condition.systemImage)
                        .font(.title3)
                        .foregroundStyle(Theme.inkSoft)
                    Text(weather.condition.displayName)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }

            Spacer()

            // ── Right: temperature ───────────────────────────────────
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(weather.apparentTemperatureCelsius))°")
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .foregroundStyle(.primary)
                Text("\(Int(weather.precipitationChance * 100))% rain")
                    .font(.caption2)
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.line, lineWidth: 0.5)
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
