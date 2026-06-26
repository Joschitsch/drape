//
//  MoodboardViewModel.swift
//  drape
//
//  Drives the Moodboard: which garment fills each slot (carrying the builder's
//  one-per-slot + dress/separates invariants), the transparent cut-outs to
//  render, and saving — either overwriting the edited outfit or branching off a
//  new one (iOS-Photos-style "Save" / "Save as New").
//

import Foundation
import SwiftData
import Observation
import UIKit

@MainActor
@Observable
final class MoodboardViewModel {
    var name: String
    var occasion: Occasion
    /// One garment per slot. A `.fullBody` (dress) is mutually exclusive with
    /// `.top`/`.bottom` — same rule as the original builder.
    var selections: [OutfitSlot: Garment]

    /// Transparent collage cut-outs and opaque fallbacks, keyed by garment id.
    private(set) var cutouts: [UUID: UIImage] = [:]
    private(set) var fallbacks: [UUID: UIImage] = [:]
    /// Garments whose cut-out is still being computed — drawn as a placeholder
    /// so the opaque canvas is never flashed mid-processing.
    private(set) var pending: Set<UUID> = []

    private let editingOutfit: Outfit?

    enum SaveMode { case overwrite, new }

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
    var isValid: Bool { !selections.isEmpty }

    /// Garments in slot order. The first is the dominant (hero) piece.
    var selectedGarments: [Garment] {
        OutfitSlot.builderOrder.compactMap { selections[$0] }
    }

    /// The dominant garment — hero of the collage and source of the auto-name.
    var lead: Garment? { selectedGarments.first }

    /// Ready-made name so saving never requires typing.
    var suggestedName: String {
        if let lead { return "\(lead.displayName) look" }
        return "\(occasion.displayName) — \(Date.now.formatted(.dateTime.month().day()))"
    }

    var resolvedName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? suggestedName : trimmed
    }

    /// Whether saving should offer the overwrite-vs-new choice.
    var offersSaveChoice: Bool { isEditing }

    // MARK: - Collage

    var placements: [PlacedGarment] {
        MoodboardLayout.place(selectedGarments)
    }

    /// Whether a garment is currently on the board (for the drawer's selected state).
    func isOnBoard(_ garment: Garment) -> Bool {
        selections[garment.category.slot]?.id == garment.id
    }

    // MARK: - Mutations

    func select(_ garment: Garment) {
        let slot = garment.category.slot
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

    /// Tapping an on-board piece toggles it off; otherwise selects it.
    func toggle(_ garment: Garment) {
        if isOnBoard(garment) {
            clear(garment.category.slot)
        } else {
            select(garment)
        }
    }

    func clear(_ slot: OutfitSlot) {
        selections[slot] = nil
    }

    // MARK: - Cut-out loading

    /// Loads transparent cut-outs (and opaque fallbacks) for every selected
    /// garment that isn't cached yet. Safe to call repeatedly.
    func loadAssets(cutout service: ImageCutoutService, store: any ImageStore) async {
        for garment in selectedGarments {
            await loadAsset(for: garment, cutout: service, store: store)
        }
    }

    /// Loads a single garment's assets — call when a new piece is added so it
    /// appears as soon as its cut-out is ready. Resolves the transparent cut-out
    /// first and only uses the opaque thumbnail as a fallback if Vision finds no
    /// subject, so the flat canvas is never shown while processing.
    func loadAsset(for garment: Garment, cutout service: ImageCutoutService, store: any ImageStore) async {
        let id = garment.id
        guard cutouts[id] == nil, fallbacks[id] == nil, !pending.contains(id) else { return }

        pending.insert(id)
        if let image = await CutoutImageCache.shared.cutoutImage(forAssetID: garment.imageAssetID, via: service) {
            cutouts[id] = image
        } else if let data = try? await store.loadThumbnailData(id: garment.thumbnailAssetID),
                  let image = UIImage(data: data) {
            fallbacks[id] = image
        }
        pending.remove(id)
    }

    // MARK: - Save

    /// Persists the board. `overwrite` updates the edited outfit in place; `new`
    /// always inserts a fresh outfit (even when editing). Throws on write failure.
    @discardableResult
    func save(into context: ModelContext, mode: SaveMode) throws -> Outfit {
        let finalName = resolvedName
        let target: Outfit

        switch mode {
        case .overwrite:
            target = editingOutfit ?? Outfit(name: finalName)
            if editingOutfit == nil { context.insert(target) }
        case .new:
            target = Outfit(name: finalName)
            context.insert(target)
        }

        target.name = finalName
        target.occasion = occasion
        target.garments = selectedGarments

        try context.save()
        return target
    }
}
