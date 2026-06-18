//
//  DebugWardrobeImporter.swift
//  drape
//
//  DEBUG-ONLY. Turns a folder/dataset of images into Garment records by running
//  the *real* autofill path — the same normalize → classify → infer-archetype →
//  store → persist sequence as the capture flow (see AddGarmentViewModel) — so we
//  can validate attribute autofill and the recommendation engine at volume
//  without photographing anything. Never compiled into release builds.
//

#if DEBUG
import Foundation
import SwiftData

/// One image to import, plus any ground-truth labels a dataset CSV provided.
struct DebugImageItem: Sendable {
    /// Stable identifier (e.g. the source filename); drives ordering and splits.
    let id: String
    let imageData: Data
    let groundTruth: DebugGroundTruth?
    /// Explicit dev/holdout assignment (e.g. from a dataset's own train/test
    /// folders). When nil, a stable hash of the id decides.
    let split: DebugSplit?

    init(id: String, imageData: Data, groundTruth: DebugGroundTruth? = nil, split: DebugSplit? = nil) {
        self.id = id
        self.imageData = imageData
        self.groundTruth = groundTruth
        self.split = split
    }
}

/// Dataset-provided labels, kept separate from our *inferred* attributes so the
/// evaluator can compare the two. Raw strings are preserved for label mapping.
nonisolated struct DebugGroundTruth: Sendable, Codable {
    var datasetID: String
    var rawCategory: String?
    var category: GarmentCategory?
    var color: ColorTag?
    var season: Season?
    var formality: Formality?

    init(datasetID: String,
         rawCategory: String? = nil,
         category: GarmentCategory? = nil,
         color: ColorTag? = nil,
         season: Season? = nil,
         formality: Formality? = nil) {
        self.datasetID = datasetID
        self.rawCategory = rawCategory
        self.category = category
        self.color = color
        self.season = season
        self.formality = formality
    }
}

/// Dev vs holdout: heuristics are tuned against `dev`, accuracy reported on
/// `holdout`, so we never "evaluate" on the same garments we tuned on.
enum DebugSplit: String, Sendable, CaseIterable { case dev, holdout }

/// What one imported garment yielded: the persisted id, its split, the dataset
/// ground truth, and the *inferred* snapshot — enough to drive metrics and the
/// review screen without re-reading SwiftData or round-tripping labels through it.
struct DebugImportRecord: Sendable {
    /// The source item id (e.g. filename) this garment came from.
    let sourceID: String
    let garmentID: UUID
    let split: DebugSplit
    let groundTruth: DebugGroundTruth?
    let inferred: GarmentSnapshot
    /// The classifier's *own* category guess, kept for evaluation even though the
    /// persisted garment may use a dataset-provided category instead.
    let classifierCategory: GarmentCategory?
    let categoryConfidence: Double

    init(sourceID: String,
         garmentID: UUID,
         split: DebugSplit,
         groundTruth: DebugGroundTruth?,
         inferred: GarmentSnapshot,
         classifierCategory: GarmentCategory? = nil,
         categoryConfidence: Double = 0) {
        self.sourceID = sourceID
        self.garmentID = garmentID
        self.split = split
        self.groundTruth = groundTruth
        self.inferred = inferred
        self.classifierCategory = classifierCategory
        self.categoryConfidence = categoryConfidence
    }
}

/// Stable, process-independent hashing. Swift's `Hasher` is seeded per run, which
/// would make splits flap between launches — FNV-1a gives us reproducible buckets.
enum StableHash {
    static func fnv1a(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Deterministic 80/20 dev/holdout split keyed by dataset + item id.
    static func split(datasetID: String, itemID: String) -> DebugSplit {
        fnv1a("\(datasetID)/\(itemID)") % 100 < 80 ? .dev : .holdout
    }
}

@MainActor
struct DebugWardrobeImporter {
    private let imageProcessor: any ImageProcessingService
    private let classifier: any GarmentClassifier
    private let styleArchetype: any StyleArchetypeInferring
    private let imageStore: any ImageStore

    init(imageProcessor: any ImageProcessingService,
         classifier: any GarmentClassifier,
         styleArchetype: any StyleArchetypeInferring,
         imageStore: any ImageStore) {
        self.imageProcessor = imageProcessor
        self.classifier = classifier
        self.styleArchetype = styleArchetype
        self.imageStore = imageStore
    }

    /// Convenience: import using the app's live services.
    init(container: AppContainer) {
        self.init(imageProcessor: container.imageProcessor,
                  classifier: container.classifier,
                  styleArchetype: container.styleArchetype,
                  imageStore: container.imageStore)
    }

    /// Imports items through the real autofill path and persists each as a
    /// `Garment`. Deterministic: items are sorted by `id` first, so import order,
    /// splits, and any downstream sampling are reproducible across runs.
    func importItems(
        _ items: [DebugImageItem],
        into context: ModelContext,
        progress: ((_ done: Int, _ total: Int) -> Void)? = nil
    ) async -> [DebugImportRecord] {
        let ordered = items.sorted { $0.id < $1.id }
        var records: [DebugImportRecord] = []
        for (idx, item) in ordered.enumerated() {
            if let record = await importOne(item, into: context) {
                records.append(record)
            }
            progress?(idx + 1, ordered.count)
        }
        try? context.save()
        return records
    }

    private func importOne(_ item: DebugImageItem, into context: ModelContext) async -> DebugImportRecord? {
        guard let processed = try? await imageProcessor.normalize(imageData: item.imageData) else { return nil }
        let suggestion = await classifier.classify(imageData: processed.imageData)

        var draft = GarmentDraft()
        draft.apply(classification: suggestion)
        // Trust a dataset-provided category over the classifier so a wrong
        // category guess doesn't cascade into the wardrobe's slot shape. The
        // evaluator still records the classifier's own guess separately.
        if let groundTruthCategory = item.groundTruth?.category { draft.category = groundTruthCategory }

        let archetype = await styleArchetype.inferArchetype(
            descriptor: suggestion.descriptor, category: draft.category, styles: [])
        if let archetype { draft.archetype = archetype }
        draft.name = "\(draft.primaryColor.displayName) \(draft.category.displayName)"

        guard let reference = try? await imageStore.save(processed) else { return nil }
        let garment = Garment(
            category: draft.category,
            primaryColor: draft.primaryColor,
            imageAssetID: reference.imageAssetID,
            thumbnailAssetID: reference.thumbnailAssetID)
        draft.apply(to: garment)
        context.insert(garment)

        let datasetID = item.groundTruth?.datasetID ?? "unlabeled"
        return DebugImportRecord(
            sourceID: item.id,
            garmentID: garment.id,
            split: item.split ?? StableHash.split(datasetID: datasetID, itemID: item.id),
            groundTruth: item.groundTruth,
            inferred: garment.snapshot,
            classifierCategory: suggestion.category,
            categoryConfidence: suggestion.categoryConfidence)
    }
}
#endif
