//
//  VisionGarmentClassifier.swift
//  drape
//
//  On-device garment classifier:
//  • VNClassifyImageRequest  → category + warmth/formality/seasons rules
//  • VNGenerateForegroundInstanceMaskRequest (same handler pass) → tight garment
//    bounding box so CIAreaAverage samples only garment pixels, not the neutral
//    canvas that VisionImageProcessingService composited in.
//
//  Footwear and bags/hats/glasses are recognised reliably. Very small accessories
//  (rings, earrings, watches) may not classify well — Vision's foreground detector
//  is trained on larger subjects, so the normalisation step may fall back to the
//  full frame and the label taxonomy has limited jewellery coverage.
//

import Vision
import CoreImage
import UIKit

struct VisionGarmentClassifier: GarmentClassifier {
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    func classify(imageData: Data) async -> ClassificationSuggestion {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else { return .empty }

        let ciImage = CIImage(cgImage: cgImage)
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        // One handler pass for both requests — shared image decoding is free.
        let classifyRequest = VNClassifyImageRequest()
        let maskRequest     = VNGenerateForegroundInstanceMaskRequest()
        try? handler.perform([classifyRequest, maskRequest])

        let observations = classifyRequest.results ?? []
        let maskObs      = maskRequest.results?.first

        let match = bestClothingMatch(from: observations)
        let color = dominantColor(of: ciImage, maskObs: maskObs, handler: handler)

        return ClassificationSuggestion(
            category:           match?.category,
            primaryColor:       color,
            categoryConfidence: Double(match?.confidence ?? 0),
            warmth:             match?.warmth,
            formality:          match?.formality,
            seasons:            match?.seasons
        )
    }

    // MARK: - Color extraction

    /// Crops the image to the tight garment bounding box (derived from the mask)
    /// before averaging, so background canvas pixels don't skew the result.
    private func dominantColor(
        of image: CIImage,
        maskObs: VNInstanceMaskObservation?,
        handler: VNImageRequestHandler
    ) -> ColorTag? {
        let cropRect: CGRect

        if let maskObs,
           let bounds = garmentBounds(maskObs: maskObs, handler: handler, imageSize: image.extent.size),
           !bounds.isEmpty {
            cropRect = bounds
        } else {
            // Fallback: inner 50 % — conservative enough to miss most of the
            // neutral canvas for typical well-framed wardrobe shots.
            let e = image.extent
            cropRect = e.insetBy(dx: e.width * 0.25, dy: e.height * 0.25)
        }

        return averageColor(of: image.cropped(to: cropRect))
    }

    /// Returns the tight bounding rect of the garment (non-zero mask pixels)
    /// in CIImage coordinates (origin bottom-left), scaled to `imageSize`.
    private func garmentBounds(
        maskObs: VNInstanceMaskObservation,
        handler: VNImageRequestHandler,
        imageSize: CGSize
    ) -> CGRect? {
        guard let pixelBuffer = try? maskObs.generateScaledMaskForImage(
            forInstances: maskObs.allInstances, from: handler) else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let w            = CVPixelBufferGetWidth(pixelBuffer)
        let h            = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow  = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let base   = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        var minX = w, maxX = -1, minY = h, maxY = -1

        // Handle both 8-bit (0–255) and 32-bit float (0.0–1.0) mask formats.
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        if format == kCVPixelFormatType_OneComponent8 {
            let bytes = base.bindMemory(to: UInt8.self, capacity: h * bytesPerRow)
            for y in 0..<h {
                for x in 0..<w where bytes[y * bytesPerRow + x] > 127 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        } else {
            let floatsPerRow = bytesPerRow / MemoryLayout<Float>.size
            let floats = base.bindMemory(to: Float.self, capacity: h * floatsPerRow)
            for y in 0..<h {
                for x in 0..<w where floats[y * floatsPerRow + x] > 0.5 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        let scaleX = imageSize.width  / CGFloat(w)
        let scaleY = imageSize.height / CGFloat(h)

        // CVPixelBuffer origin is top-left; CIImage origin is bottom-left → flip Y.
        let rect = CGRect(
            x:      CGFloat(minX) * scaleX,
            y:      CGFloat(h - maxY - 1) * scaleY,
            width:  CGFloat(maxX - minX + 1) * scaleX,
            height: CGFloat(maxY - minY + 1) * scaleY
        )

        // Inset 5 % to avoid canvas/shadow artefacts at the garment edge.
        return rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
    }

    /// CIAreaAverage over the given region, mapped to the nearest `ColorTag`.
    private func averageColor(of image: CIImage) -> ColorTag? {
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey:    image,
                  kCIInputExtentKey:   CIVector(cgRect: image.extent)]),
              let output = filter.outputImage else { return nil }

        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())
        return ColorTag.nearest(red:   Double(pixel[0]) / 255,
                                green: Double(pixel[1]) / 255,
                                blue:  Double(pixel[2]) / 255)
    }

    // MARK: - Label → property mapping

    private struct ClothingMatch {
        let category:    GarmentCategory
        let warmth:      WarmthLevel
        let formality:   Formality
        let seasons:     Set<Season>
        let confidence:  Float
        let specificity: Int  // prefer "t-shirt" (5) over "shirt" (3) over "clothing" (1)
    }

    private func bestClothingMatch(from observations: [VNClassificationObservation]) -> ClothingMatch? {
        var best: ClothingMatch?
        for obs in observations where obs.confidence > 0.05 {
            guard let p = Self.properties(for: obs.identifier.lowercased()) else { continue }
            let candidate = ClothingMatch(category: p.category, warmth: p.warmth,
                                          formality: p.formality, seasons: p.seasons,
                                          confidence: obs.confidence, specificity: p.specificity)
            if best == nil || candidate.specificity > best!.specificity { best = candidate }
        }
        return best
    }

    // swiftlint:disable cyclomatic_complexity function_body_length
    private static func properties(
        for label: String
    ) -> (category: GarmentCategory, warmth: WarmthLevel, formality: Formality,
          seasons: Set<Season>, specificity: Int)? {

        let all = Set(Season.allCases)

        // ── FOOTWEAR ──────────────────────────────────────────────────────────
        if label.contains("sneaker") || label.contains("trainer")
            || label.contains("athletic shoe") || label.contains("running shoe") {
            return (.footwear, .light, .casual, all, 5)
        }
        if label.contains("sandal") || label.contains("flip-flop") || label.contains("flip flop") {
            return (.footwear, .light, .casual, [.spring, .summer], 5)
        }
        if label.contains("high heel") || label.contains("stiletto") || label.contains("pump") {
            return (.footwear, .light, .smartCasual, [.spring, .summer, .autumn], 5)
        }
        if label.contains("loafer") || label.contains("oxford") || label.contains("derby")
            || label.contains("moccasin") {
            return (.footwear, .light, .smartCasual, all, 5)
        }
        if label.contains("boot") {
            return (.footwear, .medium, .casual, [.autumn, .winter], 4)
        }
        if label.contains("shoe") {
            return (.footwear, .light, .casual, all, 2)
        }

        // ── OUTERWEAR ─────────────────────────────────────────────────────────
        if label.contains("parka") || label.contains("anorak")
            || label.contains("down jacket") || label.contains("puffer") {
            return (.outerwear, .veryWarm, .casual, [.autumn, .winter], 6)
        }
        if label.contains("overcoat") || label.contains("trench") || label.contains("raincoat") {
            return (.outerwear, .warm, .smartCasual, [.autumn, .winter, .spring], 6)
        }
        if label.contains("blazer") || label.contains("sport coat") || label.contains("sport jacket") {
            return (.outerwear, .light, .business, all, 6)
        }
        if label.contains("windbreaker") {
            return (.outerwear, .warm, .casual, [.spring, .autumn, .winter], 5)
        }
        if label.contains("jacket") {
            return (.outerwear, .warm, .casual, [.spring, .autumn, .winter], 4)
        }
        if label.contains("coat") {
            return (.outerwear, .warm, .casual, [.autumn, .winter], 4)
        }

        // ── TOPS ──────────────────────────────────────────────────────────────
        if label.contains("t-shirt") || label.contains("tshirt") || label.contains("tee shirt") {
            return (.top, .light, .casual, [.spring, .summer], 6)
        }
        if label.contains("tank") || label.contains("camisole") || label.contains("vest top") {
            return (.top, .light, .casual, [.spring, .summer], 6)
        }
        if label.contains("hoodie") {
            return (.top, .medium, .casual, [.spring, .autumn, .winter], 6)
        }
        if label.contains("sweatshirt") || label.contains("crewneck") {
            return (.top, .medium, .casual, [.spring, .autumn, .winter], 5)
        }
        if label.contains("turtleneck") || label.contains("polo neck") {
            return (.top, .medium, .casual, [.autumn, .winter], 6)
        }
        if label.contains("sweater") || label.contains("pullover")
            || label.contains("jumper") || label.contains("knitwear") {
            return (.top, .medium, .casual, [.spring, .autumn, .winter], 5)
        }
        if label.contains("cardigan") {
            return (.top, .medium, .casual, [.spring, .autumn, .winter], 5)
        }
        if label.contains("polo shirt") {
            return (.top, .light, .smartCasual, [.spring, .summer], 6)
        }
        if label.contains("dress shirt") || label.contains("button-down") || label.contains("button down") {
            return (.top, .light, .business, all, 6)
        }
        if label.contains("blouse") {
            return (.top, .light, .smartCasual, all, 5)
        }
        if label.contains("shirt") {
            return (.top, .light, .casual, all, 3)
        }

        // ── BOTTOMS ───────────────────────────────────────────────────────────
        if label.contains("short") && !label.contains("shirt") {
            return (.bottom, .light, .casual, [.spring, .summer], 6)
        }
        if label.contains("jean") || (label.contains("denim") && label.contains("pant")) {
            return (.bottom, .medium, .casual, all, 6)
        }
        if label.contains("chino") || label.contains("khaki") || label.contains("slack") {
            return (.bottom, .medium, .smartCasual, all, 6)
        }
        if label.contains("legging") || label.contains("tights") {
            return (.bottom, .light, .casual, [.spring, .autumn, .winter], 5)
        }
        if label.contains("skirt") {
            return (.bottom, .light, .smartCasual, [.spring, .summer, .autumn], 5)
        }
        if label.contains("trouser") {
            return (.bottom, .medium, .smartCasual, all, 5)
        }
        if label.contains("pant") {
            return (.bottom, .medium, .casual, all, 3)
        }

        // ── DRESS / JUMPSUIT ──────────────────────────────────────────────────
        if label.contains("gown") || label.contains("evening dress") || label.contains("ball gown") {
            return (.dress, .light, .formal, [.spring, .summer], 6)
        }
        if label.contains("sundress") {
            return (.dress, .light, .casual, [.spring, .summer], 6)
        }
        if label.contains("dress") {
            return (.dress, .light, .smartCasual, [.spring, .summer], 4)
        }
        if label.contains("jumpsuit") || label.contains("romper") {
            return (.dress, .light, .casual, [.spring, .summer], 5)
        }

        // ── ACCESSORIES ───────────────────────────────────────────────────────
        // Bags & backpacks
        if label.contains("backpack") || label.contains("rucksack") {
            return (.accessory, .light, .casual, all, 5)
        }
        if label.contains("handbag") || label.contains("purse") || label.contains("clutch")
            || label.contains("tote") {
            return (.accessory, .light, .smartCasual, all, 5)
        }
        if label.contains("bag") {
            return (.accessory, .light, .casual, all, 3)
        }
        // Headwear
        if label.contains("baseball cap") || label.contains("beanie") || label.contains("beret") {
            return (.accessory, .light, .casual, all, 5)
        }
        if label.contains("hat") || label.contains("cap") {
            return (.accessory, .light, .casual, all, 3)
        }
        // Eyewear
        if label.contains("sunglasses") || label.contains("sunglass") {
            return (.accessory, .light, .casual, [.spring, .summer], 5)
        }
        if label.contains("glasses") || label.contains("eyeglasses") {
            return (.accessory, .light, .casual, all, 4)
        }
        // Neckwear
        if label.contains("scarf") || label.contains("muffler") {
            return (.accessory, .medium, .casual, [.autumn, .winter, .spring], 5)
        }
        if label.contains("necktie") || label.contains("bow tie") {
            return (.accessory, .light, .formal, all, 5)
        }
        if label.contains("tie") {
            return (.accessory, .light, .business, all, 3)
        }
        // Belt
        if label.contains("belt") {
            return (.accessory, .light, .casual, all, 5)
        }

        return nil
    }
    // swiftlint:enable cyclomatic_complexity function_body_length
}
