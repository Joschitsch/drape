//
//  PassthroughImageProcessingService.swift
//  drape
//
//  Step-1 placeholder. Replaced by VisionImageProcessingService (subject lift).
//

import Foundation
import CoreGraphics

/// Returns the input image unchanged as both full image and thumbnail. A
/// stand-in until the Vision-based subject-lift pipeline is implemented in the
/// wardrobe-capture step, so the app compiles and the seam exists.
struct PassthroughImageProcessingService: ImageProcessingService {
    func normalize(imageData: Data) async throws -> ProcessedImage {
        guard !imageData.isEmpty else { throw ImageProcessingError.invalidImageData }
        return ProcessedImage(imageData: imageData, thumbnailData: imageData, pixelSize: .zero)
    }
}
