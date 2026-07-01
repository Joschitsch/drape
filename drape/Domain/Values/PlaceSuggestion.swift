//
//  PlaceSuggestion.swift
//  drape
//
//  Domain value type: a named place returned by city search, used when the
//  Style tab plans looks for a location other than the user's current one.
//

import Foundation

/// A searchable place: a display label plus its coordinate. Framework-free so
/// the domain and location protocols don't depend on MapKit/CoreLocation.
struct PlaceSuggestion: Equatable, Sendable, Identifiable {
    var name: String
    var coordinate: Coordinate

    var id: String { "\(name)|\(coordinate.latitude),\(coordinate.longitude)" }

    init(name: String, coordinate: Coordinate) {
        self.name = name
        self.coordinate = coordinate
    }
}
