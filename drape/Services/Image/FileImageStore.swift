//
//  FileImageStore.swift
//  drape
//
//  Disk-backed ImageStore: garment images live as files in Application Support,
//  not in the SwiftData store.
//

import Foundation

/// Persists garment image data as PNG files under
/// `Application Support/<directoryName>`. Modelled as an `actor` so concurrent
/// captures and grid loads serialize safely and run off the main thread.
actor FileImageStore: ImageStore {
    private let directory: URL

    init(directoryName: String = "Images") {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? URL.temporaryDirectory
        directory = base.appendingPathComponent(directoryName, isDirectory: true)
    }

    func save(_ processed: ProcessedImage) async throws -> ImageAssetReference {
        try ensureDirectory()
        let imageID = "\(UUID().uuidString).png"
        let thumbID = "\(UUID().uuidString).png"
        do {
            try processed.imageData.write(to: url(for: imageID), options: .atomic)
            try processed.thumbnailData.write(to: url(for: thumbID), options: .atomic)
        } catch {
            throw ImageStoreError.writeFailed
        }
        return ImageAssetReference(imageAssetID: imageID, thumbnailAssetID: thumbID)
    }

    func loadImageData(id: String) async throws -> Data {
        try read(id)
    }

    func loadThumbnailData(id: String) async throws -> Data {
        try read(id)
    }

    func delete(_ reference: ImageAssetReference) async throws {
        for id in [reference.imageAssetID, reference.thumbnailAssetID] where !id.isEmpty {
            try? FileManager.default.removeItem(at: url(for: id))
        }
    }

    // MARK: - Helpers

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id, isDirectory: false)
    }

    private func read(_ id: String) throws -> Data {
        guard !id.isEmpty else { throw ImageStoreError.notFound }
        do {
            return try Data(contentsOf: url(for: id))
        } catch {
            throw ImageStoreError.notFound
        }
    }

    private func ensureDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
