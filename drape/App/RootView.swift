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
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }
    private var showOnboarding: Bool { !(profile?.hasCompletedOnboarding ?? true) }

    var body: some View {
        TabView {
            Tab("Wardrobe", systemImage: "tshirt") {
                WardrobeListView()
            }
            Tab("Outfits", systemImage: "figure.stand") {
                OutfitListView()
            }
            Tab("Style", systemImage: "sparkles") {
                RecommendationsView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
        .tint(Theme.ink)
        .task { PreviewData.ensureProfile(into: modelContext) }
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
