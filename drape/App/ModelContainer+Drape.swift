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
    /// The on-disk container used by the running app.
    static func drape() throws -> ModelContainer {
        try ModelContainer(for: Schema.drape)
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
