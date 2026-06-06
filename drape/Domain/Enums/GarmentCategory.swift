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

    /// SF Symbol used in lists, slot pickers and placeholders.
    var systemImage: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "rectangle.portrait.split.2x1"
        case .dress: "figure.stand.dress"
        case .footwear: "shoe"
        case .outerwear: "coat"
        case .accessory: "eyeglasses"
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

    var systemImage: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "rectangle.portrait.split.2x1"
        case .fullBody: "figure.dress.line.vertical.figure"
        case .footwear: "shoe"
        case .outerwear: "coat"
        case .accessory: "eyeglasses"
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
