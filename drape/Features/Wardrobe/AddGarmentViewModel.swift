//
//  AddGarmentViewModel.swift
//  drape
//
//  Drives the capture → normalize → classify → save flow for a new garment.
//

import Foundation
import SwiftData
import UIKit
import Observation

@MainActor
@Observable
final class AddGarmentViewModel {
    enum Phase: Equatable { case empty, processing, ready, saving }

    var phase: Phase = .empty
    /// The normalized image to preview once processing completes.
    var normalizedImage: UIImage?
    var draft = GarmentDraft()
    var errorMessage: String?

    private var processed: ProcessedImage?

    /// Normalizes the picked photo, classifies the normalized image for a more
    /// accurate dominant color, then pre-fills the draft including an auto-name.
    func handlePicked(data: Data, container: AppContainer) async {
        phase = .processing
        errorMessage = nil
        do {
            // Normalize first so color classification runs on the background-removed
            // image, avoiding the neutral canvas bleeding into the average.
            let result = try await container.imageProcessor.normalize(imageData: data)
            let suggestion = await container.classifier.classify(imageData: result.imageData)

            processed = result
            normalizedImage = UIImage(data: result.imageData)
            // Pre-fill every classifier-committed axis (silhouette/fabric/pattern
            // included); unset axes stay for the user to fill if they care.
            draft.apply(classification: suggestion)
            draft.name = Self.generateName(color: draft.primaryColor, category: draft.category)
            phase = .ready

            // Archetype is semantic — infer it after the pixel pass, off the
            // critical path, so the form is interactive while Apple Intelligence
            // (or the heuristic fallback) resolves it.
            let archetype = await container.styleArchetype.inferArchetype(
                descriptor: suggestion.descriptor,
                category: draft.category,
                styles: Array(draft.styles))
            if let archetype { draft.archetype = archetype }
        } catch {
            errorMessage = "Couldn't process that photo. Please try another."
            phase = .empty
        }
    }

    /// Produces a human-readable default name from the auto-detected attributes.
    /// e.g. "Blue Top", "Black Sneakers", "White Coat".
    private static func generateName(color: ColorTag, category: GarmentCategory) -> String {
        "\(color.displayName) \(category.displayName)"
    }

    /// Persists the normalized image and inserts the garment. Returns whether it
    /// succeeded (so the view can dismiss).
    func save(into context: ModelContext, container: AppContainer) async -> Bool {
        guard let processed else { return false }
        phase = .saving
        do {
            let reference = try await container.imageStore.save(processed)
            let garment = Garment(
                category: draft.category,
                primaryColor: draft.primaryColor,
                imageAssetID: reference.imageAssetID,
                thumbnailAssetID: reference.thumbnailAssetID
            )
            draft.apply(to: garment)
            context.insert(garment)
            try context.save()
            return true
        } catch {
            errorMessage = "Couldn't save the item. Please try again."
            phase = .ready
            return false
        }
    }
}
