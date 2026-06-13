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

    /// Saving needs at least one garment; the name always resolves to a sensible
    /// default, so it never blocks the save in the morning ritual.
    var isValid: Bool { !selections.isEmpty }

    /// A ready-made name so the user never has to type to save. Prefers the lead
    /// garment ("Navy blazer look"), falling back to occasion + date.
    var suggestedName: String {
        if let lead = selectedGarments.first {
            return "\(lead.displayName) look"
        }
        return "\(occasion.displayName) — \(Date.now.formatted(.dateTime.month().day()))"
    }

    /// The name to persist: the user's text if they typed one, else the suggestion.
    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suggestedName : trimmed
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

    /// Creates or updates the outfit. Throws if the persistence write fails so
    /// the caller can surface it instead of dismissing as if it succeeded.
    @discardableResult
    func save(into context: ModelContext) throws -> Outfit {
        let finalName = resolvedName

        let outfit = editingOutfit ?? Outfit(name: finalName)
        outfit.name = finalName
        outfit.occasion = occasion
        outfit.garments = selectedGarments

        if editingOutfit == nil {
            context.insert(outfit)
        }
        try context.save()
        return outfit
    }
}
