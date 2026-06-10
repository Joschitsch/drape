//
//  InMemoryImageStore.swift
//  drape
//
//  Step-1 placeholder. Replaced by FileImageStore (disk-backed) later.
//

import Foundation

/// Keeps image data in memory keyed by generated ids. Fine for previews and
/// Step-1 wiring; the persistent `FileImageStore` (Application Support) replaces
/// it in the wardrobe-capture step. Thread-safe via an internal actor.
final class InMemoryImageStore: ImageStore {
    private let storage = Storage()

    func save(_ processed: ProcessedImage) async throws -> ImageAssetReference {
        let imageID = UUID().uuidString
        let thumbID = UUID().uuidString
        await storage.set(imageID, processed.imageData)
        await storage.set(thumbID, processed.thumbnailData)
        return ImageAssetReference(imageAssetID: imageID, thumbnailAssetID: thumbID)
    }

    func loadImageData(id: String) async throws -> Data {
        guard let data = await storage.get(id) else { throw ImageStoreError.notFound }
        return data
    }

    func loadThumbnailData(id: String) async throws -> Data {
        try await loadImageData(id: id)
    }

    func delete(_ reference: ImageAssetReference) async throws {
        await storage.remove(reference.imageAssetID)
        await storage.remove(reference.thumbnailAssetID)
    }

    func allImageIDs() async throws -> [String] {
        await storage.keys()
    }

    private actor Storage {
        private var items: [String: Data] = [:]
        func set(_ key: String, _ value: Data) { items[key] = value }
        func get(_ key: String) -> Data? { items[key] }
        func remove(_ key: String) { items[key] = nil }
        func keys() -> [String] { Array(items.keys) }
    }
}
