//
//  EntitlementService.swift
//  drape
//
//  Domain protocol: the source of truth for what the user is entitled to.
//

import Foundation

/// Reports the user's subscription tier and gates features accordingly. The MVP
/// uses a mock with a manual free/pro toggle; real StoreKit 2 slots in behind
/// the same protocol later (see the cost constraint — no paid setup yet).
///
/// Class-bound so the concrete implementation can be `@Observable` and drive
/// SwiftUI gating reactively.
protocol EntitlementService: AnyObject {
    var tier: SubscriptionTier { get }

    /// Whether another garment may be added given the current count and tier cap.
    func canAddGarment(currentCount: Int) -> Bool

    /// Whether a Pro-gated feature is available at the current tier.
    func isEnabled(_ feature: ProFeature) -> Bool
}

extension EntitlementService {
    func canAddGarment(currentCount: Int) -> Bool {
        guard let limit = tier.garmentLimit else { return true }
        return currentCount < limit
    }

    func isEnabled(_ feature: ProFeature) -> Bool {
        tier == .pro
    }
}
