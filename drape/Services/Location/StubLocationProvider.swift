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
}
