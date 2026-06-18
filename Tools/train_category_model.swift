//
//  train_category_model.swift
//  Drape — offline tooling (NOT part of the app target)
//
//  Trains a small on-device garment-category image classifier on the CC0
//  `clothing-dataset-small` (https://github.com/alexeygrigorev/clothing-dataset-small,
//  CC0 / public domain → safe to ship). Transfer-learning over a Vision feature
//  extractor, so the resulting .mlmodel is small and runs on-device.
//
//  Usage (macOS, from the repo root):
//      swift Tools/train_category_model.swift <dataset-root> <output.mlmodel>
//  where <dataset-root> contains train/ validation/ test/ <class>/ <image>.jpg
//
//  The 10 class labels (folder names) are mapped to our six GarmentCategory cases
//  at runtime by DatasetLabelMap; the model predicts the fine-grained class.
//

import CreateML
import Foundation

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write(Data("usage: train_category_model.swift <dataset-root> <output.mlmodel>\n".utf8))
    exit(2)
}
let root = URL(fileURLWithPath: args[1], isDirectory: true)
let outURL = URL(fileURLWithPath: args[2])

let trainURL = root.appendingPathComponent("train")
let valURL = root.appendingPathComponent("validation")
let testURL = root.appendingPathComponent("test")

func pct(_ error: Double) -> String { String(format: "%.1f%%", (1 - error) * 100) }

print("Training on \(trainURL.path)")
let training = MLImageClassifier.DataSource.labeledDirectories(at: trainURL)
let classifier = try MLImageClassifier(trainingData: training)
print("Training accuracy:        \(pct(classifier.trainingMetrics.classificationError))")
print("Auto-validation accuracy: \(pct(classifier.validationMetrics.classificationError))")

// Honest held-out numbers on the dataset's own validation/test folders.
let valSource: MLImageClassifier.DataSource = .labeledDirectories(at: valURL)
print("Held-out validation:      \(pct(classifier.evaluation(on: valSource).classificationError))")
if FileManager.default.fileExists(atPath: testURL.path) {
    let testSource: MLImageClassifier.DataSource = .labeledDirectories(at: testURL)
    print("Held-out test:            \(pct(classifier.evaluation(on: testSource).classificationError))")
}

let metadata = MLModelMetadata(
    author: "Drape",
    shortDescription: "Garment category classifier (clothing-dataset-small, CC0).",
    version: "1.0")
try classifier.write(to: outURL, metadata: metadata)
print("Wrote model → \(outURL.path)")
