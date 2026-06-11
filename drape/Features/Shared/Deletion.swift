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
