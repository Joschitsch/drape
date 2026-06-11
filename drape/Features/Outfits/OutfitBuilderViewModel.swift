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
    /// The chosen garment per slot. A `.fullBody` (dress) is mutually exclusive
    /// with `.top`/`.bottom`.
    var selections: [OutfitSlot: Garment]

    /// Set when editing an existing outfit; nil when creating a new one.
    private let editingOutfit: Outfit?

    init(editing outfit: Outfit? = nil) {
        editingOutfit = outfit
        name = outfit?.name ?? ""
        occasion = outfit?.occasion ?? .everyday
        var selections: [OutfitSlot: Garment] = [:]
        for garment in outfit?.garments ?? [] {
            selections[garment.category.slot] = garment
        }
        self.selections = selections
    }

    var isEditing: Bool { editingOutfit != nil }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !selections.isEmpty
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

        let outfit = editingOutfit ?? Outfit(name: trimmedName)
        outfit.name = trimmedName
        outfit.occasion = occasion
        outfit.garments = selectedGarments

        if editingOutfit == nil {
            context.insert(outfit)
        }
        try? context.save()
        return outfit
    }
}
