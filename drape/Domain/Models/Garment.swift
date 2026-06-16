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

    var primaryColor: ColorTag = ColorTag.ink
    var secondaryColors: [ColorTag] = []
    /// Exact user-picked color (hex) for display. When set, it overrides
    /// `primaryColor` visually; `primaryColor` still holds the nearest named
    /// color so the engine can read a color family.
    var customColorHex: String? = nil

    var formality: Formality = Formality.casual
    var warmth: WarmthLevel = WarmthLevel.medium
    var seasons: [Season] = []
    var styles: [String] = []

    // Silhouette / fabric / pattern axes. Stored as raw strings (like
    // `subcategory`) so adding cases never forces a SwiftData migration; decoded
    // into enums via the computed accessors below and at the snapshot boundary.
    // All optional: nil = "not yet inferred", which the engine reads as neutral.
    var fitRaw: String?
    var topLengthRaw: String?
    var bottomVolumeRaw: String?
    var structureRaw: String?
    var fabricWeightRaw: String?
    var patternTypeRaw: String?
    var patternScaleRaw: String?

    /// User-visible label, e.g. "Blue Jeans". Auto-generated on add; editable.
    var name: String? = nil
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
        name: String? = nil,
        formality: Formality = .casual,
        warmth: WarmthLevel = .medium,
        seasons: [Season] = [],
        styles: [String] = [],
        brand: String? = nil,
        notes: String? = nil,
        imageAssetID: String = "",
        thumbnailAssetID: String = ""
    ) {
        self.id = id
        self.createdAt = .now
        self.updatedAt = .now
        self.name = name
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

    // MARK: - Style-attribute accessors
    //
    // Typed views over the raw-string storage above. Not persisted themselves
    // (SwiftData only tracks stored properties); they keep call sites readable.

    var fit: Fit? {
        get { fitRaw.flatMap(Fit.init(rawValue:)) }
        set { fitRaw = newValue?.rawValue }
    }
    var topLength: TopLength? {
        get { topLengthRaw.flatMap(TopLength.init(rawValue:)) }
        set { topLengthRaw = newValue?.rawValue }
    }
    var bottomVolume: BottomVolume? {
        get { bottomVolumeRaw.flatMap(BottomVolume.init(rawValue:)) }
        set { bottomVolumeRaw = newValue?.rawValue }
    }
    var structure: Structure? {
        get { structureRaw.flatMap(Structure.init(rawValue:)) }
        set { structureRaw = newValue?.rawValue }
    }
    var fabricWeight: FabricWeight? {
        get { fabricWeightRaw.flatMap(FabricWeight.init(rawValue:)) }
        set { fabricWeightRaw = newValue?.rawValue }
    }
    var patternType: PatternType? {
        get { patternTypeRaw.flatMap(PatternType.init(rawValue:)) }
        set { patternTypeRaw = newValue?.rawValue }
    }
    var patternScale: PatternScale? {
        get { patternScaleRaw.flatMap(PatternScale.init(rawValue:)) }
        set { patternScaleRaw = newValue?.rawValue }
    }
}
