//
//  ImageStore.swift
//  drape
//
//  Domain protocol: persist garment images outside the SwiftData store.
//

import Foundation

/// Stable handle to a stored image and its thumbnail. The ids are what gets
/// saved on `Garment`; the bytes live on disk.
struct ImageAssetReference: Sendable, Equatable {
    var imageAssetID: String
    var thumbnailAssetID: String
}

/// Persists and retrieves garment image data. Keeping binaries here (rather than
/// in SwiftData) keeps the store lean and queries fast. The MVP writes files to
/// the app's Application Support directory; a future implementation could back
/// onto a CDN or backend without changing callers.
protocol ImageStore: Sendable {
    /// Saves the full image and thumbnail, returning their identifiers.
    func save(_ processed: ProcessedImage) async throws -> ImageAssetReference

    func loadImageData(id: String) async throws -> Data
    func loadThumbnailData(id: String) async throws -> Data

    /// Removes both assets; missing files are ignored.
    func delete(_ reference: ImageAssetReference) async throws
}

enum ImageStoreError: Error {
    case notFound
    case writeFailed
}
