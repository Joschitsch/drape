//
//  DominantColorExtractor.swift
//  drape
//
//  Pure dominant-color extraction: k-means over color samples. Replaces the old
//  single-mean color readout, which mixed a garment's colors into a muddy,
//  desaturated average. Vision/CoreImage stay out of this type so the clustering
//  can be unit-tested directly with synthetic samples.
//

import Foundation

/// One color found in an image, with the share of samples it accounts for.
nonisolated struct ColorCluster: Equatable, Sendable {
    let color: PerceptualColor
    /// 0…1 fraction of the input samples assigned to this cluster.
    let weight: Double
}

/// Finds the dominant color(s) in a set of color samples via k-means. Clustering
/// happens in linear RGB so centroids are true averages of light, not of
/// gamma-encoded values; results are returned back in sRGB.
nonisolated struct DominantColorExtractor: Sendable {
    /// Number of clusters to fit. A handful is plenty for a single garment.
    var clusterCount: Int = 5
    var maxIterations: Int = 12
    /// Minimum share of samples for a cluster to count as a real color rather than
    /// noise / mask-edge bleed.
    var minClusterWeight: Double = 0.06
    /// Minimum linear-RGB distance for a secondary color to count as distinct from
    /// the colors already chosen.
    var minSeparation: Double = 0.13

    init(clusterCount: Int = 5,
         maxIterations: Int = 12,
         minClusterWeight: Double = 0.06,
         minSeparation: Double = 0.13) {
        self.clusterCount = max(1, clusterCount)
        self.maxIterations = max(1, maxIterations)
        self.minClusterWeight = minClusterWeight
        self.minSeparation = minSeparation
    }

    /// The fitted clusters, largest first. Empty when there are no samples.
    func clusters(from samples: [PerceptualColor]) -> [ColorCluster] {
        guard !samples.isEmpty else { return [] }
        let points = samples.map(Vec3.linear(from:))
        let k = min(clusterCount, points.count)
        var centroids = initialCentroids(points, k: k)

        var assignments = [Int](repeating: 0, count: points.count)
        for _ in 0..<maxIterations {
            var changed = false
            for (i, p) in points.enumerated() {
                let nearest = centroids.nearestIndex(to: p)
                if nearest != assignments[i] { assignments[i] = nearest; changed = true }
            }
            // Recompute centroids as the mean of their members; keep stragglers put.
            var sums = [Vec3](repeating: .zero, count: k)
            var counts = [Int](repeating: 0, count: k)
            for (i, p) in points.enumerated() {
                sums[assignments[i]] += p
                counts[assignments[i]] += 1
            }
            for c in 0..<k where counts[c] > 0 {
                centroids[c] = sums[c] / Double(counts[c])
            }
            if !changed { break }
        }

        var counts = [Int](repeating: 0, count: k)
        for a in assignments { counts[a] += 1 }
        let total = Double(points.count)
        return (0..<k)
            .filter { counts[$0] > 0 }
            .map { ColorCluster(color: centroids[$0].toSRGB(), weight: Double(counts[$0]) / total) }
            .sorted { $0.weight > $1.weight }
    }

    /// The dominant color first, followed by secondary colors that are both large
    /// enough and visually distinct from the colors already chosen.
    func dominant(from samples: [PerceptualColor], maxColors: Int = 3) -> [PerceptualColor] {
        let clusters = clusters(from: samples)
        guard let primary = clusters.first else { return [] }

        var picked: [Vec3] = [Vec3.linear(from: primary.color)]
        var result: [PerceptualColor] = [primary.color]
        for cluster in clusters.dropFirst() where result.count < maxColors {
            guard cluster.weight >= minClusterWeight else { continue }
            let p = Vec3.linear(from: cluster.color)
            if picked.allSatisfy({ $0.distance(to: p) >= minSeparation }) {
                picked.append(p)
                result.append(cluster.color)
            }
        }
        return result
    }

    /// Deterministic seeding: sort points by luminance and sample `k` evenly
    /// spaced ones. Spread along the light/dark axis without random state, so the
    /// result is stable and order-independent.
    private func initialCentroids(_ points: [Vec3], k: Int) -> [Vec3] {
        let sorted = points.sorted { $0.luma < $1.luma }
        guard k > 1 else { return [sorted[sorted.count / 2]] }
        return (0..<k).map { i in
            sorted[Int((Double(i) / Double(k - 1)) * Double(sorted.count - 1))]
        }
    }
}

/// A point in linear-RGB space for clustering math.
private nonisolated struct Vec3 {
    var x: Double, y: Double, z: Double
    static let zero = Vec3(x: 0, y: 0, z: 0)

    /// sRGB → linear light.
    static func linear(from c: PerceptualColor) -> Vec3 {
        Vec3(x: srgbToLinear(c.red), y: srgbToLinear(c.green), z: srgbToLinear(c.blue))
    }

    /// Linear light → sRGB color.
    func toSRGB() -> PerceptualColor {
        PerceptualColor(red: Vec3.linearToSRGB(x), green: Vec3.linearToSRGB(y), blue: Vec3.linearToSRGB(z))
    }

    /// Rec. 601 luma of the linear point — used only for stable seeding order.
    var luma: Double { 0.299 * x + 0.587 * y + 0.114 * z }

    func distance(to o: Vec3) -> Double {
        let dx = x - o.x, dy = y - o.y, dz = z - o.z
        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func += (a: inout Vec3, b: Vec3) { a = a + b }
    static func / (a: Vec3, s: Double) -> Vec3 { Vec3(x: a.x / s, y: a.y / s, z: a.z / s) }

    private static func srgbToLinear(_ c: Double) -> Double {
        c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
    private static func linearToSRGB(_ c: Double) -> Double {
        c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
    }
}

private extension Array where Element == Vec3 {
    nonisolated func nearestIndex(to p: Vec3) -> Int {
        var best = 0
        var bestD = Double.greatestFiniteMagnitude
        for (i, c) in enumerated() {
            let d = c.distance(to: p)
            if d < bestD { bestD = d; best = i }
        }
        return best
    }
}
