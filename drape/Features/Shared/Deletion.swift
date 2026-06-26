//
//  Deletion.swift
//  drape
//
//  One shared delete path for garments and outfits, so detail screens and the
//  browse grids all remove items (and clean up their images) identically, and a
//  single confirmation modifier so every "are you sure?" is the same familiar
//  bottom action sheet with consistent copy.
//

import SwiftUI
import SwiftData

// MARK: - Model deletion

/// Removes a garment from the store and asynchronously deletes its image assets.
/// Callers decide what to do afterwards (e.g. a detail view dismisses; a grid
/// stays put).
@MainActor
func deleteGarment(_ garment: Garment, context: ModelContext, imageStore: ImageStore) {
    let ref = ImageAssetReference(
        imageAssetID: garment.imageAssetID,
        thumbnailAssetID: garment.thumbnailAssetID
    )
    context.delete(garment)
    try? context.save()
    Task { try? await imageStore.delete(ref) }
}

/// Removes an outfit from the store. The garments it referenced stay in the
/// wardrobe (the relationship is severed, not the items).
@MainActor
func deleteOutfit(_ outfit: Outfit, context: ModelContext) {
    context.delete(outfit)
    try? context.save()
}

/// Undoes a just-logged wear by removing its `WearEvent`. The event's `garments`
/// is a many-to-many relationship; a plain `context.delete` leaves the garments'
/// inverse `wearEvents` still pointing at it, so SwiftData resurrects the record
/// on the next save and the wear count never drops. Detaching both sides first
/// makes the delete stick.
@MainActor
func undoWearEvent(_ event: WearEvent, context: ModelContext) {
    // Detach both sides of the many-to-many before deleting: clearing the
    // garments' inverse `wearEvents` (and the event's own arrays) stops SwiftData
    // resurrecting the record on the next save. Covered by UndoWearEventTests.
    for garment in event.garments {
        garment.wearEvents.removeAll { $0.persistentModelID == event.persistentModelID }
    }
    event.garments = []
    event.outfit = nil
    context.delete(event)
    try? context.save()
}

// MARK: - Confirmation modifier

extension View {
    /// The standard destructive confirmation — a bottom action sheet with a red
    /// **Delete** and a **Cancel**, plus a clarifying message. Used everywhere a
    /// garment or outfit can be removed so the wording and presentation match.
    func drapeDeleteConfirmation(
        title: String,
        message: String,
        isPresented: Binding<Bool>,
        onDelete: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
