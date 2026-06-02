//
//  WearEvent.swift
//  drape
//
//  SwiftData model: a record that something was worn on a date.
//

import Foundation
import SwiftData

/// Logs that an outfit (and/or a set of garments) was worn on a given day.
/// Feeds wear history, recency-aware recommendations and cost-per-wear.
///
/// Delete rules are the SwiftData default (nullify) for the relationships: a
/// wear record is history and should survive the deletion of an individual
/// garment or outfit it referenced.
@Model
final class WearEvent {
    var id: UUID = UUID()
    var date: Date = Date.now

    /// The outfit worn, if logged from a saved outfit. Inverse on `Outfit.wearEvents`.
    var outfit: Outfit?

    /// The specific garments worn. Inverse on `Garment.wearEvents`.
    var garments: [Garment] = []

    /// Temperature snapshot at the time, if weather was available. Lets us learn
    /// what the user actually wears at a given temperature later.
    var temperatureCelsius: Double?

    init(
        id: UUID = UUID(),
        date: Date = .now,
        outfit: Outfit? = nil,
        garments: [Garment] = [],
        temperatureCelsius: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.outfit = outfit
        self.garments = garments
        self.temperatureCelsius = temperatureCelsius
    }
}
