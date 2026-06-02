//
//  RecommendationsView.swift
//  drape
//
//  The AI stylist tab. Step 1: placeholder. Engine + weather land in Step 4.
//

import SwiftUI

struct RecommendationsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Style suggestions", systemImage: "sparkles")
            } description: {
                Text("Outfit recommendations based on weather, occasion and your style are coming soon.")
            }
            .navigationTitle("Style")
        }
    }
}

#Preview {
    RecommendationsView()
        .environment(AppContainer.preview())
}
