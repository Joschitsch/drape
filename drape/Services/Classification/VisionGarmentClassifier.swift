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

        // Generate the masked subject once and reuse it for color, silhouette and
        // pattern — the foreground mask turns the background transparent so every
        // pixel measurement reads the garment, not the neutral canvas.
        let maskedBuffer: CVPixelBuffer? = maskObs.flatMap {
            try? $0.generateMaskedImage(ofInstances: $0.allInstances,
                                        from: handler,
                                        croppedToInstancesExtent: true)
        }

        let color = colorFromMaskedBuffer(maskedBuffer)
            ?? fallbackColor(of: ciImage)

        let style = match.map {
            styleAttributes(category: $0.category, label: $0.label, maskedBuffer: maskedBuffer)
        } ?? .init()

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
            footwearSubcategory:  subcategory,
            fit:                  style.fit,
            topLength:            style.topLength,
            bottomVolume:         style.bottomVolume,
            structure:            style.structure,
            fabricWeight:         style.fabricWeight,
            patternType:          style.patternType,
            patternScale:         style.patternScale
        )
    }

    // MARK: - Silhouette / fabric / pattern heuristics

    /// The style axes a single garment photo can support without a dedicated model.
    private struct StyleEstimate {
        var fit: Fit?
        var topLength: TopLength?
        var bottomVolume: BottomVolume?
        var structure: Structure?
        var fabricWeight: FabricWeight?
        var patternType: PatternType?
        var patternScale: PatternScale?
    }

    /// Coarse surface statistics over the masked garment pixels.
    private struct SurfaceStats {
        let aspect: Double          // bounding-box height / width
        let fillRatio: Double       // masked coverage of the bounding box (0...1)
        let luminanceStdDev: Double // spread of brightness — high = busy surface
        let edgeDensity: Double     // mean adjacent-pixel brightness delta
    }

    private func styleAttributes(
        category: GarmentCategory,
        label: String,
        maskedBuffer: CVPixelBuffer?
    ) -> StyleEstimate {
        // Category/label priors give every clothing piece a sensible default.
        var estimate = StyleEstimate()
        let defaults = Self.styleDefaults(label: label, category: category)
        estimate.fit = defaults.fit
        estimate.structure = defaults.structure
        estimate.fabricWeight = defaults.weight

        guard let stats = maskedBuffer.flatMap(surfaceStats(maskedBuffer:)) else {
            return estimate
        }

        // Pattern: bias hard toward "solid" — only claim a print when the surface
        // is both high-contrast and busy, so folds and shadows don't read as a
        // pattern. The specific kind stays unknown (scale carries "patterned").
        if stats.luminanceStdDev > 0.14 && stats.edgeDensity > 0.06 {
            estimate.patternType = nil
            if stats.edgeDensity > 0.13 { estimate.patternScale = .small }
            else if stats.edgeDensity > 0.09 { estimate.patternScale = .medium }
            else { estimate.patternScale = .large }
        } else {
            estimate.patternType = .solid
            estimate.patternScale = PatternScale.none
        }

        // Silhouette from bounding-box geometry — applied per category.
        switch category {
        case .top:
            if stats.aspect < 0.95 { estimate.topLength = .cropped }
            else if stats.aspect > 1.5 { estimate.topLength = .long }
            else { estimate.topLength = .regular }
        case .bottom:
            // Confident only about "wide"; slim vs straight is too noisy from a box.
            if stats.fillRatio > 0.62 { estimate.bottomVolume = .wide }
        default:
            break
        }

        return estimate
    }

    /// Renders the masked subject into a small grid and measures coverage,
    /// brightness spread and edge density over the garment pixels only.
    private func surfaceStats(maskedBuffer buffer: CVPixelBuffer) -> SurfaceStats? {
        let realW = CVPixelBufferGetWidth(buffer)
        let realH = CVPixelBufferGetHeight(buffer)
        guard realW > 0, realH > 0 else { return nil }
        let aspect = Double(realH) / Double(realW)

        let side = 32
        let ci = CIImage(cvPixelBuffer: buffer)
        guard ci.extent.width > 0, ci.extent.height > 0 else { return nil }
        let scaled = ci.transformed(by: CGAffineTransform(
            scaleX: CGFloat(side) / ci.extent.width,
            y: CGFloat(side) / ci.extent.height))

        var px = [UInt8](repeating: 0, count: side * side * 4)
        ciContext.render(scaled, toBitmap: &px, rowBytes: side * 4,
                         bounds: CGRect(x: 0, y: 0, width: side, height: side),
                         format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())

        var lum = [Double?](repeating: nil, count: side * side)
        var sum = 0.0, count = 0
        for i in 0..<(side * side) {
            let a = Double(px[i * 4 + 3]) / 255
            guard a > 0.4 else { continue }   // background / soft edge
            let r = min(1, Double(px[i * 4]) / 255 / a)
            let g = min(1, Double(px[i * 4 + 1]) / 255 / a)
            let b = min(1, Double(px[i * 4 + 2]) / 255 / a)
            let l = 0.299 * r + 0.587 * g + 0.114 * b
            lum[i] = l; sum += l; count += 1
        }
        guard count > 16 else { return nil }

        let mean = sum / Double(count)
        var varSum = 0.0
        for value in lum { if let value { varSum += (value - mean) * (value - mean) } }
        let std = (varSum / Double(count)).squareRoot()

        var edgeSum = 0.0, edgeCount = 0
        for y in 0..<side {
            for x in 0..<side {
                let i = y * side + x
                guard let l = lum[i] else { continue }
                if x + 1 < side, let right = lum[i + 1] { edgeSum += abs(l - right); edgeCount += 1 }
                if y + 1 < side, let down = lum[i + side] { edgeSum += abs(l - down); edgeCount += 1 }
            }
        }
        let edge = edgeCount > 0 ? edgeSum / Double(edgeCount) : 0

        return SurfaceStats(aspect: aspect,
                            fillRatio: Double(count) / Double(side * side),
                            luminanceStdDev: std,
                            edgeDensity: edge)
    }

    /// Label-first, category-fallback priors for fit, structure and fabric weight.
    /// Rough on purpose — they seed the form; the user (and later a model) refine.
    private static func styleDefaults(
        label: String, category: GarmentCategory
    ) -> (fit: Fit?, structure: Structure?, weight: FabricWeight?) {
        if label.contains("blazer") || label.contains("suit")
            || label.contains("sport coat") || label.contains("sport jacket") {
            return (.regular, .structured, .medium)
        }
        if label.contains("trench") || label.contains("overcoat") || label.contains("coat") {
            return (.regular, .structured, .heavy)
        }
        if label.contains("puffer") || label.contains("parka")
            || label.contains("anorak") || label.contains("down jacket") {
            return (.relaxed, .structured, .heavy)
        }
        if label.contains("hoodie") || label.contains("sweatshirt") {
            return (.relaxed, .soft, .medium)
        }
        if label.contains("sweater") || label.contains("cardigan") || label.contains("pullover")
            || label.contains("jumper") || label.contains("knit") || label.contains("turtleneck") {
            return (.regular, .soft, .heavy)
        }
        if label.contains("dress shirt") || label.contains("button") || label.contains("blouse") {
            return (.regular, .semiStructured, .light)
        }
        if label.contains("t-shirt") || label.contains("tshirt") || label.contains("tee")
            || label.contains("tank") || label.contains("camisole") {
            return (.regular, .soft, .light)
        }
        if label.contains("jean") || label.contains("denim") {
            return (.regular, .semiStructured, .medium)
        }
        if label.contains("chino") || label.contains("trouser") || label.contains("slack") {
            return (.regular, .semiStructured, .medium)
        }
        if label.contains("legging") || label.contains("tights") {
            return (.slim, .soft, .light)
        }
        switch category {
        case .top:                  return (.regular, .soft, .light)
        case .bottom:               return (.regular, .semiStructured, .medium)
        case .dress:                return (.regular, .soft, .light)
        case .outerwear:            return (.regular, .structured, .medium)
        case .footwear, .accessory: return (nil, nil, nil)
        }
    }

    // MARK: - Color extraction

    /// Inner-crop average mapped to the nearest `ColorTag` — the fallback when no
    /// foreground mask is available. Misses most canvas on well-framed shots.
    private func fallbackColor(of image: CIImage) -> ColorTag? {
        let e = image.extent
        return averageColor(of: image.cropped(to: e.insetBy(dx: e.width * 0.25, dy: e.height * 0.25)))
    }

    /// Alpha-weighted average over the masked subject: the foreground mask turns
    /// the background transparent, so `CIAreaAverage` (premultiplied) divided by
    /// the average alpha yields the true garment color with no canvas bleed.
    private func colorFromMaskedBuffer(_ buffer: CVPixelBuffer?) -> ColorTag? {
        guard let buffer else { return nil }
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
        let label:       String  // lowercased identifier that won, for style priors
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
            let label = obs.identifier.lowercased()
            guard let p = Self.properties(for: label) else { continue }
            let candidate = ClothingMatch(category: p.category, warmth: p.warmth,
                                          formality: p.formality, seasons: p.seasons,
                                          confidence: obs.confidence, specificity: p.specificity,
                                          label: label)
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
