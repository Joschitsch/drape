//
//  AttributeEval.swift
//  drape
//
//  DEBUG-ONLY. Scores inferred garment attributes against dataset ground truth,
//  uniformly across every axis. Each attribute reports:
//    • coverage     — how often we committed a value (predicted / total)
//    • distribution — spread of inferred values across the enum's cases
//    • accuracy     — correct / (labeled ∧ predicted), only when the dataset
//                     actually labels that axis (else nil → shown as "—")
//  So visually-derivable axes (pattern/texture/silhouette) are measurable even
//  with no labels, and accuracy "lights up" automatically when a richer labeled
//  dataset is used — no shape change required.
//

#if DEBUG
import Foundation

/// One bin of an attribute's value distribution.
struct DistributionBin: Sendable, Equatable {
    let value: String
    let count: Int
}

/// Per-attribute coverage / accuracy / distribution over a set of records.
struct AttributeMetric: Sendable {
    let name: String
    let total: Int          // records considered
    let predicted: Int      // inferred value present (population coverage)
    let labeled: Int        // ground truth present
    let scored: Int         // labeled AND predicted (accuracy denominator)
    let correct: Int        // scored AND match
    let distribution: [DistributionBin]

    /// How many items received any value. Trivially full for non-optional axes
    /// (formality/warmth) — the distribution is the signal there.
    var coverage: Double { total == 0 ? 0 : Double(predicted) / Double(total) }
    /// nil when the dataset doesn't label this axis (nothing to score against).
    var accuracy: Double? { scored == 0 ? nil : Double(correct) / Double(scored) }
}

/// One concrete miss, for eyeballing alongside the garment thumbnail.
struct ConfusionEntry: Sendable, Equatable {
    let sourceID: String
    let attribute: String
    let expected: String
    let got: String
}

/// Aggregated category confusion (expected → got, with a count).
struct ConfusionBin: Sendable, Equatable {
    let expected: String
    let got: String
    let count: Int
}

struct AttributeEvalReport: Sendable {
    let split: DebugSplit?
    let total: Int
    let metrics: [AttributeMetric]
    let confusions: [ConfusionEntry]   // a capped sample of category misses
    let confusionTally: [ConfusionBin] // category misses aggregated, most-common first

    func metric(_ name: String) -> AttributeMetric? { metrics.first { $0.name == name } }
}

enum AttributeEval {
    /// One attribute reduced to comparable strings: its ground-truth value (nil =
    /// unlabeled) and its inferred value (nil = not committed).
    struct AttributeSpec {
        let name: String
        let groundTruth: @Sendable (DebugImportRecord) -> String?
        let inferred: @Sendable (DebugImportRecord) -> String?
    }

    /// Every axis we evaluate. Category accuracy uses the classifier's *own* guess
    /// (not the persisted, possibly ground-truth-overridden, category). Color is
    /// judged at family granularity, which is what the engine reasons about.
    static var specs: [AttributeSpec] {
        [
            .init(name: "category",
                  groundTruth: { $0.groundTruth?.category?.rawValue },
                  inferred: { $0.classifierCategory?.rawValue }),
            .init(name: "colorFamily",
                  groundTruth: { $0.groundTruth?.color?.family.rawValue },
                  inferred: { $0.inferred.primaryColor.family.rawValue }),
            .init(name: "formality",
                  groundTruth: { $0.groundTruth?.formality.map { String($0.rawValue) } },
                  inferred: { String($0.inferred.formality.rawValue) }),
            .init(name: "warmth",
                  groundTruth: { _ in nil },   // no dataset labels warmth yet
                  inferred: { String($0.inferred.warmth.rawValue) }),
            .init(name: "season",
                  groundTruth: { $0.groundTruth?.season?.rawValue },
                  // Multi-valued: "predicted" = any season; "correct" = contains GT.
                  inferred: { rec in rec.inferred.seasons.isEmpty ? nil
                      : rec.inferred.seasons.map(\.rawValue).sorted().joined(separator: "+") }),
            .init(name: "fit",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.fit?.rawValue }),
            .init(name: "topLength",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.topLength?.rawValue }),
            .init(name: "bottomVolume",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.bottomVolume?.rawValue }),
            .init(name: "structure",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.structure?.rawValue }),
            .init(name: "fabricWeight",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.fabricWeight?.rawValue }),
            .init(name: "patternType",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.patternType?.rawValue }),
            .init(name: "patternScale",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.patternScale?.rawValue }),
            .init(name: "texture",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.texture?.rawValue }),
            .init(name: "archetype",
                  groundTruth: { _ in nil },
                  inferred: { $0.inferred.archetype?.rawValue }),
        ]
    }

    static func evaluate(
        _ records: [DebugImportRecord],
        on split: DebugSplit? = .holdout,
        maxConfusions: Int = 50
    ) -> AttributeEvalReport {
        let scoped = split.map { s in records.filter { $0.split == s } } ?? records

        let metrics = specs.map { metric(for: $0, over: scoped) }

        // Category confusions: sample (capped) + aggregated tally.
        var samples: [ConfusionEntry] = []
        var tally: [String: Int] = [:]   // "expected→got" → count
        let category = specs.first { $0.name == "category" }!
        for r in scoped {
            guard let expected = category.groundTruth(r), let got = category.inferred(r), expected != got else { continue }
            samples.append(.init(sourceID: r.sourceID, attribute: "category", expected: expected, got: got))
            tally["\(expected)→\(got)", default: 0] += 1
        }
        let confusionTally = tally
            .map { key, count -> ConfusionBin in
                let parts = key.split(separator: "→", maxSplits: 1)
                return ConfusionBin(expected: String(parts[0]), got: String(parts.count > 1 ? parts[1] : ""), count: count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.expected < $1.expected }

        return AttributeEvalReport(
            split: split,
            total: scoped.count,
            metrics: metrics,
            confusions: Array(samples.sorted { $0.sourceID < $1.sourceID }.prefix(maxConfusions)),
            confusionTally: confusionTally)
    }

    private static func metric(for spec: AttributeSpec, over records: [DebugImportRecord]) -> AttributeMetric {
        var predicted = 0, labeled = 0, scored = 0, correct = 0
        var bins: [String: Int] = [:]
        for r in records {
            let gt = spec.groundTruth(r)
            let inf = spec.inferred(r)
            if gt != nil { labeled += 1 }
            if let inf {
                predicted += 1
                bins[inf, default: 0] += 1
                if let gt {
                    scored += 1
                    if gt == inf { correct += 1 }
                }
            }
        }
        let distribution = bins
            .map { DistributionBin(value: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.value < $1.value }
        return AttributeMetric(
            name: spec.name, total: records.count, predicted: predicted,
            labeled: labeled, scored: scored, correct: correct, distribution: distribution)
    }
}
#endif
