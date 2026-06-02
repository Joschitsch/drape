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

    var body: some View {
        TabView {
            Tab("Wardrobe", systemImage: "tshirt") {
                WardrobeListView()
            }
            Tab("Outfits", systemImage: "square.stack.3d.up") {
                OutfitListView()
            }
            Tab("Style", systemImage: "sparkles") {
                RecommendationsView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
        .task { PreviewData.ensureProfile(into: modelContext) }
    }
}

#Preview {
    let container = AppContainer.preview()
    RootView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
