//
//  OnboardingViewModel.swift
//  drape
//

import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    /// Occasions surfaced in the onboarding flow, in order.
    static let occasions: [Occasion] = [.everyday, .work, .date, .formal]

    /// Draft preferences keyed by occasion. Nil means the step was skipped.
    private(set) var drafts: [Occasion: OccasionPreference] = [:]

    /// Global style fallback (last step).
    var globalStyles: Set<String> = []

    var currentStep: Int = 0

    var totalSteps: Int { Self.occasions.count + 2 } // welcome + occasions + global styles

    var isOnLastStep: Bool { currentStep == totalSteps - 1 }

    func draft(for occasion: Occasion) -> OccasionPreference {
        drafts[occasion] ?? OccasionPreference(
            occasion: occasion,
            targetFormality: occasion.targetFormality,
            styles: []
        )
    }

    func update(occasion: Occasion, formality: Formality, styles: Set<String>) {
        drafts[occasion] = OccasionPreference(
            occasion: occasion,
            targetFormality: formality,
            styles: Array(styles)
        )
    }

    func next() {
        if currentStep < totalSteps - 1 { currentStep += 1 }
    }

    func back() {
        if currentStep > 0 { currentStep -= 1 }
    }

    func apply(to profile: UserProfile) {
        profile.occasionPreferences = drafts.values.map { $0 }
        if !globalStyles.isEmpty {
            profile.preferredStyles = Array(globalStyles)
        }
        profile.hasCompletedOnboarding = true
    }
}
