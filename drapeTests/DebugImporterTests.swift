//
//  DebugImporterTests.swift
//  drapeTests
//
//  Phase 1 backbone: the debug wardrobe importer turns images into persisted
//  Garments through the real autofill path, deterministically. Uses synthetic
//  images (plumbing only) so it runs unattended in CI.
//

#if DEBUG
import Foundation
import Testing
import SwiftData
@testable import drape

@MainActor
@Suite("Debug wardrobe importer", .serialized)
struct DebugImporterTests {
    private func makeImporter(store: InMemoryImageStore) -> DebugWardrobeImporter {
        DebugWardrobeImporter(
            imageProcessor: PassthroughImageProcessingService(),
            classifier: StubGarmentClassifier(),
            styleArchetype: HeuristicStyleArchetypeModel(),
            imageStore: store)
    }

    @Test("Imports every item as a persisted garment with a resolvable image")
    func importsPersistGarments() async throws {
        let container = ModelContainer.previewContainer(seeded: false)
        let store = InMemoryImageStore()
        let items = SyntheticDebugImageProvider.smokeItems(count: 12)

        let records = await makeImporter(store: store).importItems(items, into: container.mainContext)

        #expect(records.count == 12)
        let garments = try container.mainContext.fetch(FetchDescriptor<Garment>())
        #expect(garments.count == 12)
        #expect(garments.allSatisfy { !$0.imageAssetID.isEmpty })

        // Every garment's image resolves from the same store the importer used.
        for garment in garments {
            let data = try await store.loadImageData(id: garment.imageAssetID)
            #expect(!data.isEmpty)
        }
    }

    @Test("Import is deterministic in order and split across runs")
    func importIsDeterministic() async {
        let items = SyntheticDebugImageProvider.smokeItems(count: 16)

        // Bind containers to locals so they outlive the import (a temporary
        // ModelContainer would be deallocated while its context is still in use).
        let containerA = ModelContainer.previewContainer(seeded: false)
        let containerB = ModelContainer.previewContainer(seeded: false)
        let first = await makeImporter(store: InMemoryImageStore())
            .importItems(items, into: containerA.mainContext)
        let second = await makeImporter(store: InMemoryImageStore())
            .importItems(items.shuffled(), into: containerB.mainContext)

        // Same source order (sorted by id) and same split assignment regardless
        // of input order or run.
        #expect(first.map(\.sourceID) == second.map(\.sourceID))
        #expect(first.map(\.sourceID) == first.map(\.sourceID).sorted())
        #expect(first.map(\.split) == second.map(\.split))
    }

    @Test("Stable split keeps the same item in the same bucket every time")
    func splitIsStable() {
        let a = StableHash.split(datasetID: "synthetic", itemID: "synthetic_001_top_navy")
        let b = StableHash.split(datasetID: "synthetic", itemID: "synthetic_001_top_navy")
        #expect(a == b)
        // Both buckets are actually used across a realistic id range.
        let buckets = (0..<200).map { StableHash.split(datasetID: "d", itemID: "img_\($0)") }
        #expect(buckets.contains(.dev))
        #expect(buckets.contains(.holdout))
    }
}

@Suite("Debug wardrobe selection")
struct DebugWardrobeSelectionTests {
    private func record(_ snapshot: GarmentSnapshot, id: String) -> DebugImportRecord {
        DebugImportRecord(sourceID: id, garmentID: snapshot.id, split: .dev,
                          groundTruth: nil, inferred: snapshot)
    }

    @Test("Themed wardrobes select by inferred attributes")
    func themedSelection() {
        let records = [
            record(garment(.top, formality: .business), id: "a"),
            record(garment(.top, archetype: .streetwear), id: "b"),
            record(garment(.bottom, archetype: .preppy), id: "c"),
            record(garment(.footwear, archetype: .sporty), id: "d"),
        ]
        let office = DebugWardrobe.classicOffice.select(from: records).map(\.sourceID)
        let street = DebugWardrobe.streetwear.select(from: records).map(\.sourceID)

        #expect(office.contains("a"))        // business formality
        #expect(office.contains("c"))        // preppy archetype
        #expect(street.contains("b"))
        #expect(street.contains("d"))
        #expect(!office.contains("b"))
    }

    @Test("Mixed selection is deterministic and capped")
    func mixedDeterministic() {
        let records = (0..<100).map { record(garment(.top), id: String(format: "i_%03d", $0)) }
        let a = DebugWardrobe.mixed.select(from: records, limit: 20).map(\.sourceID)
        let b = DebugWardrobe.mixed.select(from: records, limit: 20).map(\.sourceID)
        #expect(a.count == 20)
        #expect(a == b)
    }
}
#endif
