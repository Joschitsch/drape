//
//  StubLocationProvider.swift
//  drape
//
//  Fixed-coordinate location stub. Replaced by CoreLocationProvider later.
//

import Foundation

/// Returns a fixed coordinate (defaults to Berlin). Placeholder until the
/// CoreLocation-backed provider is added in the recommendations step; also
/// useful for previews and tests.
struct StubLocationProvider: LocationProvider {
    var coordinate: Coordinate

    init(coordinate: Coordinate = Coordinate(latitude: 52.52, longitude: 13.405)) {
        self.coordinate = coordinate
    }

    func currentCoordinate() async throws -> Coordinate {
        coordinate
    }

    func placeName(for coordinate: Coordinate) async -> String? { "Berlin" }

    /// A few fixed cities filtered by query, so the location picker renders in
    /// previews and tests without hitting MapKit.
    func search(query: String) async -> [PlaceSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let samples = [
            PlaceSuggestion(name: "Paris, France", coordinate: Coordinate(latitude: 48.8566, longitude: 2.3522)),
            PlaceSuggestion(name: "London, England", coordinate: Coordinate(latitude: 51.5074, longitude: -0.1278)),
            PlaceSuggestion(name: "New York, NY", coordinate: Coordinate(latitude: 40.7128, longitude: -74.0060)),
            PlaceSuggestion(name: "Tokyo, Japan", coordinate: Coordinate(latitude: 35.6762, longitude: 139.6503)),
            PlaceSuggestion(name: "Berlin, Germany", coordinate: Coordinate(latitude: 52.52, longitude: 13.405))
        ]
        return samples.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
    }
}
