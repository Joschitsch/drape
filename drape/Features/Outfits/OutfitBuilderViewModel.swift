//
//  OutfitBuilderViewModel.swift
//  drape
//
//  Drives assembling garments into an outfit (one item per slot) and saving it.
//

import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class OutfitBuilderViewModel {
    var name: String
    var occasion: Occasion
    /// Comma-separated tags, parsed on save.
    var tagsText: String
    /// The chosen garment per slot. A `.fullBody` (dress) is mutually exclusive
    /// with `.top`/`.bottom`.
    var selections: [OutfitSlot: Garment]

    /// Set when editing an existing outfit; nil when creating a new one.
    private let editingOutfit: Outfit?

    init(editing outfit: Outfit? = nil) {
        editingOutfit = outfit
        name = outfit?.name ?? ""
        occasion = outfit?.occasion ?? .everyday
        tagsText = outfit?.tags.joined(separator: ", ") ?? ""
        var selections: [OutfitSlot: Garment] = [:]
        for garment in outfit?.garments ?? [] {
            selections[garment.category.slot] = garment
        }
        self.selections = selections
    }

    var isEditing: Bool { editingOutfit != nil }

    /// Valid when named, with footwear and either a dress or both a top and a
    /// bottom.
    var isValid: Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        let hasFootwear = selections[.footwear] != nil
        let hasCore = selections[.fullBody] != nil || (selections[.top] != nil && selections[.bottom] != nil)
        return hasFootwear && hasCore
    }

    /// Garments in slot order, for persisting and previewing.
    var selectedGarments: [Garment] {
        OutfitSlot.builderOrder.compactMap { selections[$0] }
    }

    func select(_ garment: Garment, for slot: OutfitSlot) {
        selections[slot] = garment
        // Keep dress and top/bottom mutually exclusive.
        switch slot {
        case .fullBody:
            selections[.top] = nil
            selections[.bottom] = nil
        case .top, .bottom:
            selections[.fullBody] = nil
        default:
            break
        }
    }

    func clear(_ slot: OutfitSlot) {
        selections[slot] = nil
    }

    /// Creates or updates the outfit. Returns the saved outfit.
    @discardableResult
    func save(into context: ModelContext) -> Outfit {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let tags = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let outfit = editingOutfit ?? Outfit(name: trimmedName)
        outfit.name = trimmedName
        outfit.occasion = occasion
        outfit.tags = tags
        outfit.garments = selectedGarments

        if editingOutfit == nil {
            context.insert(outfit)
        }
        try? context.save()
        return outfit
    }
}
