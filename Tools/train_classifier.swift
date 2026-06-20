//
//  train_classifier.swift
//  Drape — offline tooling (NOT part of the app target)
//
//  Generalised CreateML trainer for the on-device garment classifiers. Same
//  transfer-learning recipe as the original train_category_model.swift (small,
//  on-device .mlmodel), but parameterised by *axis* so it trains either the
//  category or the pattern model from a Create ML `labeledDirectories` tree.
//
//  The dataset trees are produced by Tools/build_training_data.py, which also
//  writes the MODEL_CARD.md provenance entry up front (dataset, license, class
//  histogram). This trainer *appends* the held-out accuracy to that entry, so a
//  model card always reflects both where the data came from and how the model
//  scored.
//
//  Usage (macOS, from the repo root):
//      swift Tools/train_classifier.swift <axis> <dataset-root> <output.mlmodel> [model-card.md]
//  where:
//      <axis>         category | pattern  (label only — affects metadata + card)
//      <dataset-root> contains train/ validation/ test/ <class>/ <image>.jpg
//      [model-card]   optional MODEL_CARD.md to append the accuracy block to
//
//  Class balancing / augmentation is done at data-prep time (see the Python
//  script), so the training call here stays minimal and API-stable.
//

import CreateML
import Foundation

let args = CommandLine.arguments
guard args.count >= 4 else {
    FileHandle.standardError.write(Data(
        "usage: train_classifier.swift <axis> <dataset-root> <output.mlmodel> [model-card.md]\n".utf8))
    exit(2)
}
let axis = args[1]
let root = URL(fileURLWithPath: args[2], isDirectory: true)
let outURL = URL(fileURLWithPath: args[3])
let cardURL = args.count >= 5 ? URL(fileURLWithPath: args[4]) : nil

let trainURL = root.appendingPathComponent("train")
let valURL = root.appendingPathComponent("validation")
let testURL = root.appendingPathComponent("test")

func pct(_ error: Double) -> String { String(format: "%.1f%%", (1 - error) * 100) }

print("Training \(axis) model on \(trainURL.path)")
let training = MLImageClassifier.DataSource.labeledDirectories(at: trainURL)
let classifier = try MLImageClassifier(trainingData: training)
print("Training accuracy:        \(pct(classifier.trainingMetrics.classificationError))")
print("Auto-validation accuracy: \(pct(classifier.validationMetrics.classificationError))")

// Honest held-out numbers on the dataset's own validation/test folders.
let valError = classifier.evaluation(
    on: .labeledDirectories(at: valURL)).classificationError
print("Held-out validation:      \(pct(valError))")

var testError: Double?
if FileManager.default.fileExists(atPath: testURL.path) {
    let err = classifier.evaluation(on: .labeledDirectories(at: testURL)).classificationError
    testError = err
    print("Held-out test:            \(pct(err))")
}

let metadata = MLModelMetadata(
    author: "Drape",
    shortDescription: "Garment \(axis) classifier (see MODEL_CARD.md for dataset + license).",
    version: "1.0")
try classifier.write(to: outURL, metadata: metadata)
print("Wrote model → \(outURL.path)")

// Append the held-out accuracy to the provenance entry the prep step created.
if let cardURL {
    let stamp = ISO8601DateFormatter().string(from: Date())
    var block = "\n#### \(axis) — accuracy (trained \(stamp))\n"
    block += "- Held-out validation: \(pct(valError))\n"
    if let testError { block += "- Held-out test: \(pct(testError))\n" }
    if let handle = try? FileHandle(forWritingTo: cardURL) {
        handle.seekToEndOfFile()
        handle.write(Data(block.utf8))
        try? handle.close()
        print("Appended accuracy → \(cardURL.path)")
    } else {
        try? block.write(to: cardURL, atomically: true, encoding: .utf8)
    }
}
