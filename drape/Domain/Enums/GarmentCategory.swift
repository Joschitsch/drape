//
//  GarmentCategory.swift
//  drape
//
//  Domain enum: the top-level kind of a wardrobe item.
//

import Foundation

/// The category a garment belongs to. Drives the outfit slot it can fill and
/// default filtering in the wardrobe. String-backed so it persists stably in
/// SwiftData even if cases are reordered.
enum GarmentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case top
    case bottom
    case dress
    case footwear
    case outerwear
    case accessory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .dress: "Dress"
        case .footwear: "Footwear"
        case .outerwear: "Outerwear"
        case .accessory: "Accessory"
        }
    }

    /// Custom symbol (Assets.xcassets) used in lists, slot pickers and chrome.
    /// The same silhouette family as the museum-canvas `CategoryGlyph`.
    var iconName: String {
        switch self {
        case .top: "drape.top"
        case .bottom: "drape.bottom"
        case .dress: "drape.dress"
        case .footwear: "drape.footwear"
        case .outerwear: "drape.outerwear"
        case .accessory: "drape.accessory"
        }
    }

    /// Which outfit slot this category occupies. A `dress` fills the combined
    /// top+bottom role, which the outfit builder treats specially.
    var slot: OutfitSlot {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .dress: .fullBody
        case .footwear: .footwear
        case .outerwear: .outerwear
        case .accessory: .accessory
        }
    }
}

/// A position within an outfit. Used by the builder and recommendation engine
/// to assemble one garment per role.
enum OutfitSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case top
    case bottom
    case fullBody   // a dress satisfies both top and bottom
    case footwear
    case outerwear  // optional
    case accessory  // optional, may repeat

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: "Top"
        case .bottom: "Bottom"
        case .fullBody: "Dress"
        case .footwear: "Footwear"
        case .outerwear: "Outerwear"
        case .accessory: "Accessory"
        }
    }

    var iconName: String {
        switch self {
        case .top: "drape.top"
        case .bottom: "drape.bottom"
        case .fullBody: "drape.dress"   // aligned with GarmentCategory.dress
        case .footwear: "drape.footwear"
        case .outerwear: "drape.outerwear"
        case .accessory: "drape.accessory"
        }
    }

    /// Slots an outfit is not considered complete without (a dress substitutes
    /// for top+bottom; this is resolved in the recommendation engine).
    static var required: [OutfitSlot] { [.top, .bottom, .footwear] }

    /// Order the slots are presented in the outfit builder.
    static var builderOrder: [OutfitSlot] {
        [.fullBody, .top, .bottom, .footwear, .outerwear, .accessory]
    }
}
