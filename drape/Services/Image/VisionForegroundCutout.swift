//
//  VisionForegroundCutout.swift
//  drape
//
//  Shared on-device subject isolation: lift the foreground garment off its
//  background with Vision and return it as a transparent image. Used both by the
//  capture pipeline (composited onto a neutral canvas) and by the Moodboard
//  (kept transparent for the overlapping collage).
//

import Foundation
import Vision
import CoreImage

enum VisionForegroundCutout {
    /// Returns the foreground subject as a `CIImage` with a transparent
    /// background, cropped to the subject's extent. Throws if no subject is found.
    nonisolated static func maskedImage(from cgImage: CGImage) throws -> CIImage {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let result = request.results?.first, !result.allInstances.isEmpty else {
            throw ImageProcessingError.subjectNotFound
        }

        let masked = try result.generateMaskedImage(
            ofInstances: result.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        return CIImage(cvPixelBuffer: masked)
    }
}
