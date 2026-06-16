//
//  AppContainer.swift
//  drape
//
//  Composition root: owns the concrete service implementations and hands them
//  to the view layer via the SwiftUI environment.
//

import Foundation
import Observation

/// Central dependency container. Services are held behind their protocols so a
/// concrete implementation can be swapped (e.g. stub → Vision, mock → Open-Meteo,
/// mock → StoreKit) without touching call sites.
///
/// `@Observable` so it can be injected with `.environment(_:)` and read with
/// `@Environment(AppContainer.self)`. `@MainActor` because it's constructed and
/// consumed from the UI layer.
@MainActor
@Observable
final class AppContainer {
    let imageProcessor: any ImageProcessingService
    let imageStore: any ImageStore
    let classifier: any GarmentClassifier
    /// Infers a garment's style archetype at add-time (Foundation Models, with a
    /// heuristic fallback). Separate from `classifier` because it's semantic, not
    /// pixel-based, and may hop off-device to Apple Intelligence.
    let styleArchetype: any StyleArchetypeInferring
    let weather: any WeatherService
    let location: any LocationProvider
    let recommendationEngine: any RecommendationEngine

    /// Kept as the concrete `@Observable` type (not behind the protocol) so
    /// SwiftUI can observe live tier changes for feature gating. This is the one
    /// service whose concrete type the environment depends on; swapping to
    /// StoreKit later means introducing a shared observable store here.
    let entitlements: MockEntitlementService

    init(
        imageProcessor: any ImageProcessingService,
        imageStore: any ImageStore,
        classifier: any GarmentClassifier,
        styleArchetype: any StyleArchetypeInferring,
        weather: any WeatherService,
        location: any LocationProvider,
        recommendationEngine: any RecommendationEngine,
        entitlements: MockEntitlementService
    ) {
        self.imageProcessor = imageProcessor
        self.imageStore = imageStore
        self.classifier = classifier
        self.styleArchetype = styleArchetype
        self.weather = weather
        self.location = location
        self.recommendationEngine = recommendationEngine
        self.entitlements = entitlements
    }

    /// The container used by the running app. As later steps land their real
    /// implementations, swap the placeholders here (one line each).
    static func live() -> AppContainer {
        AppContainer(
            imageProcessor: VisionImageProcessingService(),
            imageStore: FileImageStore(),
            classifier: VisionGarmentClassifier(),
            styleArchetype: FoundationModelsStyleArchetypeModel(),
            weather: OpenMeteoWeatherService(),          // free, no key (Step 4)
            location: CoreLocationProvider(),            // Step 4
            recommendationEngine: RuleBasedRecommendationEngine(), // Step 4
            entitlements: MockEntitlementService()
        )
    }

    /// A container for SwiftUI previews and tests (deterministic, in-memory).
    static func preview(tier: SubscriptionTier = .free) -> AppContainer {
        AppContainer(
            imageProcessor: PassthroughImageProcessingService(),
            imageStore: InMemoryImageStore(),
            classifier: StubGarmentClassifier(),
            styleArchetype: HeuristicStyleArchetypeModel(),
            weather: MockWeatherService(),
            location: StubLocationProvider(),
            recommendationEngine: StubRecommendationEngine(),
            entitlements: MockEntitlementService(tier: tier)
        )
    }
}
