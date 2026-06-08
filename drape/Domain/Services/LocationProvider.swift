//
//  LocationProvider.swift
//  drape
//
//  Domain protocol: obtain the user's current coordinate.
//

import Foundation

/// Supplies the user's current coordinate for weather lookups. The MVP wraps
/// CoreLocation; tests/previews use a fixed-coordinate stub. Returns a domain
/// `Coordinate` so callers never import CoreLocation.
protocol LocationProvider: Sendable {
    func currentCoordinate() async throws -> Coordinate
    /// A human-readable place name (locality) for a coordinate, for display in
    /// the weather widget. Best-effort; returns nil if unavailable.
    func placeName(for coordinate: Coordinate) async -> String?
}

extension LocationProvider {
    func placeName(for coordinate: Coordinate) async -> String? { nil }
}

enum LocationError: Error {
    case permissionDenied
    case unavailable
}
