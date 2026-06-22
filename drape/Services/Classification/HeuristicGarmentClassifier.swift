//
//  HeuristicGarmentClassifier.swift
//  drape
//
//  Best-effort attribute guesses without ML: averages the garment's dominant
//  color and maps it to the nearest palette entry.
//

import Foundation
import CoreImage
import UIKit

/// Guesses a garment's `primaryColor` from the average color of the image's
/// central region (where the item usually sits, avoiding edge background).
/// Category is left to the user — reliable category prediction is the job of a
/// Core ML model added later, for which this type is the seam.
struct HeuristicGarmentClassifier: GarmentClassifier {
    /// Fraction of width/height sampled from the center.
    var centerFraction: CGFloat = 0.6
    private let context = CIContext(options: [.workingColorSpace: NSNull()])

    func classify(imageData: Data) async -> ClassificationSuggestion {
        guard let uiImage = UIImage(data: imageData), let cgImage = uiImage.cgImage else {
            return .empty
        }
        let image = CIImage(cgImage: cgImage)
        let extent = image.extent
        let crop = CGRect(
            x: extent.midX - extent.width * centerFraction / 2,
            y: extent.midY - extent.height * centerFraction / 2,
            width: extent.width * centerFraction,
            height: extent.height * centerFraction
        )

        guard let avg = averageColor(of: image.cropped(to: crop)) else { return .empty }
        let color = PerceptualColor(red: avg.0, green: avg.1, blue: avg.2)
        let tag = ColorTag.nearest(red: avg.0, green: avg.1, blue: avg.2)
        // Color is a hint, not a certainty; category is deliberately unset.
        return ClassificationSuggestion(primaryColor: tag, primaryColorHex: color.hex, categoryConfidence: 0)
    }

    /// Reduces a region to its single average sRGB color via `CIAreaAverage`.
    private func averageColor(of image: CIImage) -> (Double, Double, Double)? {
        guard image.extent.width >= 1, image.extent.height >= 1,
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: image,
                  kCIInputExtentKey: CIVector(cgRect: image.extent),
              ]),
              let output = filter.outputImage else {
            return nil
        }

        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(
            output,
            toBitmap: &pixel,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        return (Double(pixel[0]) / 255, Double(pixel[1]) / 255, Double(pixel[2]) / 255)
    }
}
