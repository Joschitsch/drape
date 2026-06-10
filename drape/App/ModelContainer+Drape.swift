//
//  ModelContainer+Drape.swift
//  drape
//
//  Central SwiftData schema and container factories.
//

import Foundation
import SwiftData

extension Schema {
    /// The single source of truth for the persisted model types. Add new
    /// `@Model` types here.
    static var drape: Schema {
        Schema([
            Garment.self,
            Outfit.self,
            WearEvent.self,
            UserProfile.self,
        ])
    }
}

extension ModelContainer {
    /// The on-disk container used by the running app. If the existing store is
    /// incompatible with the current schema and SwiftData can't auto-migrate
    /// (e.g. an attribute's type changed), recover by resetting the local store
    /// instead of crashing — demo data reseeds on next launch. Appropriate for a
    /// pre-release app; a production build would ship a `SchemaMigrationPlan`.
    static func drape() throws -> ModelContainer {
        let config = ModelConfiguration(schema: .drape)
        do {
            return try ModelContainer(for: Schema.drape, configurations: config)
        } catch {
            deleteStore(at: config.url)
            return try ModelContainer(for: Schema.drape, configurations: config)
        }
    }

    /// Removes the SQLite store and its sidecar files.
    private static func deleteStore(at url: URL) {
        let fm = FileManager.default
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            try? fm.removeItem(atPath: path)
        }
    }

    /// An in-memory container for previews and tests, optionally seeded with
    /// sample data.
    @MainActor
    static func previewContainer(seeded: Bool = true) -> ModelContainer {
        do {
            let container = try ModelContainer(
                for: Schema.drape,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            if seeded {
                PreviewData.seed(into: container.mainContext)
            }
            return container
        } catch {
            fatalError("Failed to build preview ModelContainer: \(error)")
        }
    }
}
