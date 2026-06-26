//
//  FeatureFlags.swift
//  drape
//
//  Compile-time/runtime switches for in-progress surfaces. Kept tiny and
//  centralised so a feature can be backed out without touching call sites.
//

import Foundation

enum FeatureFlags {
    /// When `true`, the new editorial Moodboard replaces the slot-based
    /// `OutfitBuilderView` as the create/edit-outfit surface. Flip to `false` to
    /// instantly restore the original builder — the builder code is retained.
    static let useMoodboardBuilder = true
}
