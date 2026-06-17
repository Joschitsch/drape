//
//  AttributeEval.swift
//  drape
//
//  DEBUG-ONLY. Scores inferred garment attributes against dataset ground truth:
//  per-attribute accuracy + coverage, plus a confusion list of the worst misses.
//  Runs on the holdout split by default so we never report on garments we tuned
//  heuristics against.
//

#if DEBUG
import Foundation

/// Accuracy + coverage for one attribute over a set of records.
///   coverage = of records that *have* ground truth, how many we committed a value
///   accuracy = of the values we committed, how many matched
struct AttributeMetric: Sendable, Equatable {
    let name: String
    let evaluated: Int   // records carrying ground truth for this attribute
    let covered: Int     // of those, how many we committed a (non-nil) value
    let correct: Int     // of covered, how many matched ground truth

    var accuracy: Double { covered == 0 ? 0 : Double(correct) / Double(covered) }
    var coverage: Double { evaluated == 0 ? 0 : Double(covered) / Double(evaluated) }
}

/// One concrete miss, for eyeballing alongside the garment thumbnail.
struct ConfusionEntry: Sendable, Equatable {
    let sourceID: String
    let attribute: String
    let expected: String
    let got: String
}

struct AttributeEvalReport: Sendable {
    let split: DebugSplit?
    let total: Int
    let metrics: [AttributeMetric]
    let confusions: [ConfusionEntry]

    func metric(_ name: String) -> AttributeMetric? { metrics.first { $0.name == name } }
}

enum AttributeEval {
    /// Evaluates `records`, restricted to `split` when given. Category is judged on
    /// the classifier's *own* guess (not the persisted, possibly ground-truth
    /// overridden, category); color is judged at family granularity, which is what
    /// the engine actually reasons about.
    static func evaluate(
        _ records: [DebugImportRecord],
        on split: DebugSplit? = .holdout,
        maxConfusions: Int = 50
    ) -> AttributeEvalReport {
        let scoped = split.map { s in records.filter { $0.split == s } } ?? records
        var confusions: [ConfusionEntry] = []

        // ── Category (classifier guess vs ground truth) ──────────────────────
        var catEval = 0, catCovered = 0, catCorrect = 0
        for r in scoped {
            guard let expected = r.groundTruth?.category else { continue }
            catEval += 1
            guard let got = r.classifierCategory else { continue }   // uncovered
            catCovered += 1
            if got == expected { catCorrect += 1 }
            else { confusions.append(.init(sourceID: r.sourceID, attribute: "category",
                                           expected: expected.rawValue, got: got.rawValue)) }
        }

        // ── Color family (inferred vs ground truth) ──────────────────────────
        var colEval = 0, colCovered = 0, colCorrect = 0
        for r in scoped {
            guard let expected = r.groundTruth?.color else { continue }
            colEval += 1
            colCovered += 1   // primaryColor is always committed
            if r.inferred.primaryColor.family == expected.family { colCorrect += 1 }
            else { confusions.append(.init(sourceID: r.sourceID, attribute: "colorFamily",
                                           expected: expected.family.rawValue,
                                           got: r.inferred.primaryColor.family.rawValue)) }
        }

        let metrics = [
            AttributeMetric(name: "category", evaluated: catEval, covered: catCovered, correct: catCorrect),
            AttributeMetric(name: "colorFamily", evaluated: colEval, covered: colCovered, correct: colCorrect),
        ]
        // Stable ordering for the confusion list (sourceID) so review pages don't flap.
        let trimmed = Array(confusions.sorted { $0.sourceID < $1.sourceID }.prefix(maxConfusions))
        return AttributeEvalReport(split: split, total: scoped.count, metrics: metrics, confusions: trimmed)
    }
}
#endif
