//
//  ProfileView.swift
//  drape
//
//  Profile + entitlement tier. Step 1: read-only prefs + a dev tier toggle.
//  Full editing and paywall land in Step 5.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(MockEntitlementService.self) private var entitlements

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        @Bindable var entitlements = entitlements
        return NavigationStack {
            Form {
                if let profile {
                    Section("Preferred styles") {
                        chips(profile.preferredStyles.map(\.displayName))
                    }
                    Section("Preferred colors") {
                        chips(profile.preferredColors.map(\.displayName),
                              swatches: profile.preferredColors.map(\.color))
                    }
                    Section("Default formality") {
                        Text(profile.defaultFormality.displayName)
                    }
                }

                Section {
                    Picker("Tier", selection: $entitlements.tier) {
                        ForEach(SubscriptionTier.allCases) { tier in
                            Text(tier.displayName).tag(tier)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(entitlements.tier == .pro
                         ? "Pro features unlocked."
                         : "Free tier — up to \(SubscriptionTier.free.garmentLimit ?? 0) items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Subscription")
                } footer: {
                    Text("Dev toggle — real purchasing is added later.")
                }
            }
            .navigationTitle("Profile")
        }
    }

    private func chips(_ labels: [String], swatches: [Color]? = nil) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { offset, label in
                    TagChip(label, swatch: swatches?[safe: offset])
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let container = AppContainer.preview()
    ProfileView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
