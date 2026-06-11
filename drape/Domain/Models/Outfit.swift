//
//  Outfit.swift
//  drape
//
//  SwiftData model: a saved combination of garments.
//

import Foundation
import SwiftData

/// A named combination of garments the user has put together. The same garment
/// can belong to many outfits (many-to-many).
@Model
final class Outfit {
    var id: UUID = UUID()
    var name: String = ""
    var createdAt: Date = Date.now

    /// The garments making up this outfit. Inverse declared on `Garment.outfits`.
    var garments: [Garment] = []

    var occasion: Occasion = Occasion.everyday
    var notes: String?

    @Relationship(inverse: \WearEvent.outfit)
    var wearEvents: [WearEvent] = []

    init(
        id: UUID = UUID(),
        name: String,
        garments: [Garment] = [],
        occasion: Occasion = .everyday,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = .now
        self.garments = garments
        self.occasion = occasion
        self.notes = notes
    }

    var wearCount: Int { wearEvents.count }
}
