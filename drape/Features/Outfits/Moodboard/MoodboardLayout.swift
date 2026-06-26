//
//  MoodboardLayout.swift
//  drape
//
//  Editorial collage placement. Pieces sit upright (no rotation) on a single
//  shared vertical centre axis — a clean "ghost mannequin" stack — with only the
//  natural anatomical overlap where garments connect (top hem over waistband,
//  shoe toe under the cuff). Outerwear, when worn with a top, layers behind it
//  rather than stacking as a separate row.
//
//  All positions and sizes are fractions of the canvas, so the same outfit
//  renders as the identical composition at any canvas size (thumbnail ↔ detail).
//

import Foundation
import CoreGraphics

/// A garment positioned on the collage in normalized space (0...1 of the canvas).
struct PlacedGarment: Identifiable, Equatable {
    let id: UUID
    /// Centre of the piece, as a fraction of the canvas width/height.
    var center: CGPoint
    /// Bounding box the piece is fit within (scaledToFit), as fractions of the
    /// canvas width/height. Fitting by box keeps every garment a consistent
    /// visual size regardless of its cut-out aspect ratio.
    var widthFraction: CGFloat
    var heightFraction: CGFloat
    /// Higher draws on top.
    var zIndex: Double
    /// Direction the soft shadow falls, in degrees (90 = straight down).
    var shadowAngle: Double
    /// Shadow blur radius as a fraction of the piece width.
    var shadowRadiusFraction: CGFloat
}

enum MoodboardLayout {
    /// Canonical width:height ratio the collage is composed for. Rendering at this
    /// aspect everywhere keeps thumbnail and detail visually identical.
    static let aspectRatio: CGFloat = 0.8

    /// Per-slot anchor: band centre (x always 0.5 — shared spine), bounding box
    /// (w×h), and z-order. Bands are separated with only light anatomical
    /// overlap. z back→front: outerwear < bottom < footwear < top/dress < accessory.
    private struct SlotAnchor {
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var z: Double
    }

    private static func anchor(for slot: OutfitSlot) -> SlotAnchor {
        switch slot {
        case .top:       SlotAnchor(y: 0.22, width: 0.52, height: 0.32, z: 3)
        case .outerwear: SlotAnchor(y: 0.22, width: 0.56, height: 0.36, z: 0)
        case .bottom:    SlotAnchor(y: 0.52, width: 0.48, height: 0.36, z: 1)
        case .footwear:  SlotAnchor(y: 0.79, width: 0.30, height: 0.15, z: 2)
        case .fullBody:  SlotAnchor(y: 0.40, width: 0.50, height: 0.58, z: 3)
        case .accessory: SlotAnchor(y: 0.93, width: 0.22, height: 0.14, z: 4)
        }
    }

    /// Lays garments onto the board. Order of the input doesn't affect any
    /// piece's transform; the result is sorted back→front for drawing.
    static func place(_ garments: [Garment]) -> [PlacedGarment] {
        let hasTop = garments.contains { $0.category.slot == .top }
        return garments
            .map { placed($0, hasTop: hasTop) }
            .sorted { $0.zIndex < $1.zIndex }
    }

    private static func placed(_ garment: Garment, hasTop: Bool) -> PlacedGarment {
        let slot = garment.category.slot
        var a = anchor(for: slot)
        var y = a.y

        // Outerwear worn over a top: layer it behind the top (same centre), a
        // touch lower and ~15% larger so its collar and shoulders frame the top.
        if slot == .outerwear, hasTop {
            let top = anchor(for: .top)
            y = top.y + 0.03
            a.width = top.width * 1.15
            a.height = top.height * 1.15
            // z stays 0 (behind the top).
        }

        // Shadow varied per piece so none match — the only seeded value left.
        var rng = SeededGenerator(seed: garment.id)
        let shadowAngle = 90.0 + rng.next(in: -35.0...35.0)
        let shadowRadius = CGFloat(rng.next(in: 0.04...0.07))

        return PlacedGarment(
            id: garment.id,
            center: CGPoint(x: 0.5, y: y),
            widthFraction: a.width,
            heightFraction: a.height,
            zIndex: a.z,
            shadowAngle: shadowAngle,
            shadowRadiusFraction: shadowRadius
        )
    }
}

/// A tiny deterministic PRNG seeded from a UUID's bytes, so per-piece shadow
/// variation is stable across launches (Swift's `Hashable` is per-process
/// randomized and unsuitable).
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UUID) {
        var hash: UInt64 = 0xcbf29ce484222325
        withUnsafeBytes(of: seed.uuid) { bytes in
            for byte in bytes {
                hash ^= UInt64(byte)
                hash = hash &* 0x100000001b3
            }
        }
        state = hash == 0 ? 0x9e3779b97f4a7c15 : hash
    }

    private mutating func nextUnit() -> Double {
        state = state &+ 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        z = z ^ (z >> 31)
        return Double(z >> 11) * (1.0 / 9007199254740992.0)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextUnit() * (range.upperBound - range.lowerBound)
    }
}
