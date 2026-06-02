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

    /// Normalizes the picked photo and classifies it (run concurrently), then
    /// pre-fills the draft with any confident guesses.
    func handlePicked(data: Data, container: AppContainer) async {
        phase = .processing
        errorMessage = nil
        do {
            // Normalization and classification are independent — run in parallel.
            async let normalized = container.imageProcessor.normalize(imageData: data)
            let suggestion = await container.classifier.classify(imageData: data)
            let result = try await normalized

            processed = result
            normalizedImage = UIImage(data: result.imageData)
            if let color = suggestion.primaryColor { draft.primaryColor = color }
            if let category = suggestion.category { draft.category = category }
            phase = .ready
        } catch {
            errorMessage = "Couldn't process that photo. Please try another."
            phase = .empty
        }
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
