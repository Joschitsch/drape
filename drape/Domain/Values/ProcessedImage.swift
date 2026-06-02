//
//  ProcessedImage.swift
//  drape
//
//  Domain value type: output of the image normalization pipeline.
//

import Foundation

/// The result of normalising a captured photo: the garment cut out and
/// composited onto a consistent neutral canvas, plus a small thumbnail.
/// Carried as raw PNG `Data` so the domain stays free of UIKit/CoreGraphics;
/// the `ImageStore` persists it and the UI decodes it.
struct ProcessedImage: Sendable {
    var imageData: Data
    var thumbnailData: Data
    /// Pixel dimensions of the full image, for layout hints.
    var pixelSize: CGSize

    init(imageData: Data, thumbnailData: Data, pixelSize: CGSize) {
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.pixelSize = pixelSize
    }
}
