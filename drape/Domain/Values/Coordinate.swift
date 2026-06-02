//
//  Coordinate.swift
//  drape
//
//  Domain value type: a plain lat/lon pair.
//

import Foundation

/// A geographic coordinate, independent of CoreLocation so the domain and the
/// weather/location protocols don't depend on a specific framework.
struct Coordinate: Equatable, Sendable {
    var latitude: Double
    var longitude: Double

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
