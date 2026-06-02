//
//  ImageProcessingService.swift
//  drape
//
//  Domain protocol: normalise a captured photo into a consistent wardrobe image.
//

import Foundation

/// Turns a raw captured/library photo into a normalised `ProcessedImage`:
/// subject cut from its background and composited onto a consistent neutral
/// canvas, plus a thumbnail.
///
/// Input is raw image `Data` (as delivered by `PhotosPicker`/camera) so this
/// protocol carries no UIKit types. The MVP implementation uses on-device
/// Vision; it can later be swapped for a server-side or higher-quality model.
protocol ImageProcessingService: Sendable {
    func normalize(imageData: Data) async throws -> ProcessedImage
}

enum ImageProcessingError: Error {
    case invalidImageData
    case subjectNotFound
    case renderingFailed
}
