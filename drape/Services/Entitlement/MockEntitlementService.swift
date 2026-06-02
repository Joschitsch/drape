//
//  MockEntitlementService.swift
//  drape
//
//  MVP entitlement source: a manual free/pro toggle (no StoreKit yet).
//

import Foundation
import Observation

/// In-memory entitlement provider used until real StoreKit 2 is wired (per the
/// project cost constraint). `@Observable` so flipping `tier` live-updates any
/// gated UI. The tier is persisted to `UserDefaults` so the choice survives
/// relaunches during development.
@Observable
final class MockEntitlementService: EntitlementService {
    var tier: SubscriptionTier {
        didSet { UserDefaults.standard.set(tier.rawValue, forKey: Self.defaultsKey) }
    }

    private static let defaultsKey = "mockEntitlementTier"

    init(tier: SubscriptionTier? = nil) {
        if let tier {
            self.tier = tier
        } else {
            let stored = UserDefaults.standard.string(forKey: Self.defaultsKey)
            self.tier = stored.flatMap(SubscriptionTier.init(rawValue:)) ?? .free
        }
    }

    // canAddGarment / isEnabled come from the protocol's default implementation.
}
