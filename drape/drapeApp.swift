//
//  drapeApp.swift
//  drape
//
//  Created by Joscha Axthammer on 02.06.26.
//

import SwiftUI
import SwiftData

@main
struct drapeApp: App {
    /// The persistent SwiftData store, created once for the app's lifetime.
    private let modelContainer: ModelContainer
    /// Dependency container holding the service implementations.
    @State private var appContainer = AppContainer.live()

    init() {
        do {
            modelContainer = try .drape()
        } catch {
            fatalError("Failed to create the SwiftData ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appContainer)
                .environment(appContainer.entitlements)
        }
        .modelContainer(modelContainer)
    }
}
