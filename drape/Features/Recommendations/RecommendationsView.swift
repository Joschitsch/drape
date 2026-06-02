//
//  RecommendationsView.swift
//  drape
//
//  AI stylist tab: occasion picker → weather → ranked outfit suggestions.
//

import SwiftUI
import SwiftData

struct RecommendationsView: View {
    @Query(filter: #Predicate<Garment> { !$0.isArchived })
    private var wardrobe: [Garment]

    @Query private var profiles: [UserProfile]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var model = RecommendationsViewModel()

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                occasionPicker
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
                Divider()
                content
            }
            .navigationTitle("Style")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await model.refresh(wardrobe: wardrobe, profile: profile, container: container) }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .task { await model.refresh(wardrobe: wardrobe, profile: profile, container: container) }
        .onChange(of: model.occasion) {
            Task { await model.refresh(wardrobe: wardrobe, profile: profile, container: container) }
        }
        .onChange(of: wardrobe) {
            Task { await model.refresh(wardrobe: wardrobe, profile: profile, container: container) }
        }
    }

    // MARK: - Sub-views

    private var occasionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Occasion.allCases) { occasion in
                    let selected = model.occasion == occasion
                    Button { model.occasion = occasion } label: {
                        Label(occasion.displayName, systemImage: occasion.systemImage)
                            .font(.subheadline)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.thinMaterial),
                                in: Capsule()
                            )
                            .foregroundStyle(selected ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            Spacer()
        case .loading:
            VStack(spacing: 16) {
                ProgressView()
                Text("Finding outfits…").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .results:
            resultsList
        case .error(let msg):
            ContentUnavailableView("Couldn't load suggestions", systemImage: "exclamationmark.triangle", description: Text(msg))
        }
    }

    private var resultsList: some View {
        ScrollView {
            if let summary = model.weatherSummary {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 12)
            }

            if model.suggestions.isEmpty {
                ContentUnavailableView(
                    "Not enough items",
                    systemImage: "tshirt",
                    description: Text("Add more wardrobe items — you need at least footwear and a top + bottom (or a dress) to get suggestions.")
                )
                .padding(.top, 32)
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(Array(model.suggestions.enumerated()), id: \.offset) { index, item in
                        SuggestionCard(
                            rank: index + 1,
                            suggestion: item.suggestion,
                            garments: item.garments,
                            onSave: { save(item.suggestion, garments: item.garments) }
                        )
                    }
                }
                .padding(Theme.contentPadding)
            }
        }
    }

    private func save(_ suggestion: OutfitSuggestion, garments: [Garment]) {
        let outfit = Outfit(
            name: "Outfit \(Date.now.formatted(date: .abbreviated, time: .omitted))",
            garments: garments,
            occasion: model.occasion
        )
        modelContext.insert(outfit)
        try? modelContext.save()
    }
}

// MARK: - Suggestion card

private struct SuggestionCard: View {
    let rank: Int
    let suggestion: OutfitSuggestion
    let garments: [Garment]
    let onSave: () -> Void

    @State private var saved = false

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: rank + score bar
            HStack {
                Text("#\(rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                ScoreBar(score: suggestion.score)
            }

            // Garment grid
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(garments) { garment in
                    NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category)
                        .aspectRatio(1, contentMode: .fit)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Rationale chips
            if !suggestion.rationale.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(suggestion.rationale, id: \.self) { reason in
                            TagChip(reason)
                        }
                    }
                }
            }

            // Actions
            HStack {
                Button {
                    onSave()
                    saved = true
                } label: {
                    Label(saved ? "Saved" : "Save outfit", systemImage: saved ? "checkmark" : "plus")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .disabled(saved)
            }
        }
        .padding(Theme.contentPadding)
        .background(.background, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
    }
}

/// A thin horizontal bar showing the outfit's score as a fraction filled.
private struct ScoreBar: View {
    let score: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(scoreColor)
                    .frame(width: geo.size.width * score)
            }
        }
        .frame(width: 80, height: 6)
    }

    private var scoreColor: Color {
        score > 0.75 ? .green : score > 0.5 ? .orange : .red
    }
}

#Preview {
    let container = AppContainer.preview()
    RecommendationsView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
