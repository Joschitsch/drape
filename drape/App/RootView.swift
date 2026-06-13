//
//  RootView.swift
//  drape
//
//  Top-level tab shell. Seeds a profile + demo content on first launch.
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var showOnboarding: Bool { !(profile?.hasCompletedOnboarding ?? true) }

    var body: some View {
        TabView {
            Tab("Style", image: "drape.style") {
                RecommendationsView()
            }
            Tab("Wardrobe", image: "drape.wardrobe") {
                WardrobeListView()
            }
            Tab("Outfits", image: "drape.outfits") {
                OutfitListView()
            }
            Tab("Profile", image: "drape.profile") {
                ProfileView()
            }
        }
        .tint(Theme.ink)
        // Honor Dynamic Type, but clamp so the dense editorial layout scales
        // generously without collapsing at the largest accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .task {
            PreviewData.ensureProfile(into: modelContext)
            await PreviewData.backfillImages(context: modelContext, imageStore: container.imageStore)
        }
        .fullScreenCover(isPresented: .constant(showOnboarding)) {
            if let profile {
                OnboardingView(profile: profile)
            }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    RootView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
