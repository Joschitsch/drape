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
        let subcategory = match?.category == .footwear
            ? bestFootwearSubcategory(from: observations)
            : nil

        return ClassificationSuggestion(
            category:             match?.category,
            primaryColor:         color,
            categoryConfidence:   Double(match?.confidence ?? 0),
            warmth:               match?.warmth,
            formality:            match?.formality,
            seasons:              match?.seasons,
            footwearSubcategory:  subcategory
        )
    }

    // MARK: - Color extraction

    /// Averages **only the garment pixels** (background excluded) and maps the
    /// result to the nearest `ColorTag`. Falls back to an inner-crop average when
    /// no foreground mask is available.
    private func dominantColor(
        of image: CIImage,
        maskObs: VNInstanceMaskObservation?,
        handler: VNImageRequestHandler
    ) -> ColorTag? {
        if let maskObs, let color = maskedAverageColor(maskObs: maskObs, handler: handler) {
            return color
        }
        // Fallback: inner 50 % — misses most of the canvas on well-framed shots.
        let e = image.extent
        return averageColor(of: image.cropped(to: e.insetBy(dx: e.width * 0.25, dy: e.height * 0.25)))
    }

    /// Alpha-weighted average over the masked subject: the foreground mask turns
    /// the background transparent, so `CIAreaAverage` (premultiplied) divided by
    /// the average alpha yields the true garment color with no canvas bleed.
    private func maskedAverageColor(
        maskObs: VNInstanceMaskObservation,
        handler: VNImageRequestHandler
    ) -> ColorTag? {
        guard let buffer = try? maskObs.generateMaskedImage(
                  ofInstances: maskObs.allInstances,
                  from: handler,
                  croppedToInstancesExtent: true) else { return nil }
        let masked = CIImage(cvPixelBuffer: buffer)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey:  masked,
                  kCIInputExtentKey: CIVector(cgRect: masked.extent)]),
              let output = filter.outputImage else { return nil }

        var px = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &px, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                         format: .RGBA8,
                         colorSpace: CGColorSpaceCreateDeviceRGB())

        let a = Double(px[3]) / 255
        guard a > 0.02 else { return nil }   // essentially no subject
        // Un-premultiply to recover the straight garment color.
        let r = min(1, Double(px[0]) / 255 / a)
        let g = min(1, Double(px[1]) / 255 / a)
        let b = min(1, Double(px[2]) / 255 / a)
        return ColorTag.nearest(red: r, green: g, blue: b)
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

    private func bestFootwearSubcategory(from observations: [VNClassificationObservation]) -> FootwearSubcategory? {
        for obs in observations.sorted(by: { $0.confidence > $1.confidence }) where obs.confidence > 0.05 {
            let label = obs.identifier.lowercased()
            if label.contains("sneaker") || label.contains("trainer")
                || label.contains("athletic shoe") || label.contains("running shoe") { return .athletic }
            if label.contains("sandal") || label.contains("flip-flop")
                || label.contains("flip flop") { return .sandal }
            if label.contains("high heel") || label.contains("stiletto")
                || label.contains("pump") { return .dress }
            if label.contains("loafer") || label.contains("oxford") || label.contains("derby")
                || label.contains("moccasin") { return .loafer }
            if label.contains("boot") { return .boot }
        }
        return nil
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
