//
//  Garment.swift
//  drape
//
//  SwiftData model: a single wardrobe item.
//

import Foundation
import SwiftData

/// One item of clothing in the user's wardrobe.
///
/// Image bytes are *not* stored here — only stable asset identifiers that the
/// `ImageStore` resolves to files on disk. This keeps the SwiftData store small
/// and fast. Enum attributes are `Codable`, which SwiftData persists directly.
@Model
final class Garment {
    /// Stable identity independent of SwiftData's PersistentIdentifier; handy
    /// for diffing, sharing and a future backend sync.
    var id: UUID = UUID()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now

    /// Identifiers into `ImageStore`. Empty string means "no image yet".
    var imageAssetID: String = ""
    var thumbnailAssetID: String = ""

    var category: GarmentCategory = GarmentCategory.top
    var subcategory: String?

    var primaryColor: ColorTag = ColorTag.black
    var secondaryColors: [ColorTag] = []

    var formality: Formality = Formality.casual
    var warmth: WarmthLevel = WarmthLevel.medium
    var seasons: [Season] = []
    var styles: [StyleTag] = []

    var brand: String?
    /// Optional purchase price, enabling cost-per-wear analytics (Pro).
    var purchasePrice: Decimal?
    var notes: String?

    var isFavorite: Bool = false
    /// Archived items stay for history/analytics but are hidden from the grid
    /// and excluded from recommendations.
    var isArchived: Bool = false

    // Inverses are declared on this side only (see Outfit / WearEvent).
    @Relationship(inverse: \Outfit.garments)
    var outfits: [Outfit] = []

    @Relationship(inverse: \WearEvent.garments)
    var wearEvents: [WearEvent] = []

    init(
        id: UUID = UUID(),
        category: GarmentCategory,
        primaryColor: ColorTag,
        formality: Formality = .casual,
        warmth: WarmthLevel = .medium,
        seasons: [Season] = [],
        styles: [StyleTag] = [],
        brand: String? = nil,
        notes: String? = nil,
        imageAssetID: String = "",
        thumbnailAssetID: String = ""
    ) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
        self.category = category
        self.primaryColor = primaryColor
        self.formality = formality
        self.warmth = warmth
        self.seasons = seasons
        self.styles = styles
        self.brand = brand
        self.notes = notes
        self.imageAssetID = imageAssetID
        self.thumbnailAssetID = thumbnailAssetID
    }

    /// Number of times this item has been worn — drives cost-per-wear and the
    /// "rarely used" analytics.
    var wearCount: Int { wearEvents.count }
}
