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
    /// Forward city search: turns a free-text query into matching places, so the
    /// user can plan looks for a location other than where they are. Best-effort;
    /// returns an empty array on failure or empty query.
    func search(query: String) async -> [PlaceSuggestion]
}

extension LocationProvider {
    func placeName(for coordinate: Coordinate) async -> String? { nil }
    func search(query: String) async -> [PlaceSuggestion] { [] }
}

enum LocationError: Error {
    case permissionDenied
    case unavailable
}
