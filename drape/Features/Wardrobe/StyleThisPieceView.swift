//
//  StyleThisPieceView.swift
//  drape
//
//  "Style this piece": locks one garment and asks the engine to build outfits
//  around it. Reuses the whole rule-based engine via RecommendationContext's
//  lockedGarmentID — no new scoring, just a constrained candidate set.
//

import SwiftUI
import SwiftData

struct StyleThisPieceView: View {
    let garment: Garment

    @Query(filter: #Predicate<Garment> { !$0.isArchived })
    private var wardrobe: [Garment]
    @Query private var profiles: [UserProfile]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var occasion: Occasion = .everyday
    @State private var results: [(suggestion: OutfitSuggestion, garments: [Garment])] = []
    @State private var isLoading = true

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    MonoLabel("Building looks around")
                    SerifText(garment.displayName, size: 22)

                    SingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                                      selection: $occasion)

                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if results.isEmpty {
                        ContentUnavailableView(
                            "No looks yet",
                            image: "drape.style",
                            description: Text("Couldn't build an outfit around this piece for \(occasion.displayName.lowercased()). Try another occasion or add more items."))
                    } else {
                        ForEach(Array(results.enumerated()), id: \.offset) { _, item in
                            StyleSuggestionMiniCard(
                                suggestion: item.suggestion,
                                garments: item.garments,
                                onSave: { save(item.garments) })
                        }
                    }
                }
                .padding(Theme.contentPadding)
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle("Style this piece")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
            .task(id: occasion) { await run() }
        }
    }

    private func run() async {
        isLoading = true
        let recentWears: [UUID: Date] = Dictionary(
            wardrobe.flatMap { g in
                g.wearEvents.compactMap { e -> (UUID, Date)? in
                    guard e.date > Date.now.addingTimeInterval(-14 * 86_400) else { return nil }
                    return (g.id, e.date)
                }
            },
            uniquingKeysWith: { max($0, $1) })

        let prefs = ProfilePreferences(
            preferredStyles: profile?.preferredStyles ?? [],
            occasionPreferences: profile?.occasionPreferences ?? [],
            tuning: profile?.styleTuning ?? StyleTuning())

        // Weather is intentionally omitted — this flow is about pairing, not the
        // forecast, so the warmth scorer stays neutral.
        let context = RecommendationContext(
            wardrobe: wardrobe.map(\.snapshot),
            occasion: occasion,
            profile: prefs,
            recentWears: recentWears,
            desiredCount: 4,
            lockedGarmentID: garment.id)

        let raw = await container.recommendationEngine.recommend(context)
        let lookup = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id, $0) })
        results = raw.map { ($0, $0.garmentIDs.compactMap { lookup[$0] }) }
        isLoading = false
    }

    private func save(_ garments: [Garment]) {
        let outfit = Outfit(
            name: "Outfit \(Date.now.formatted(date: .abbreviated, time: .omitted))",
            garments: garments,
            occasion: occasion)
        modelContext.insert(outfit)
        try? modelContext.save()
    }
}

private struct StyleSuggestionMiniCard: View {
    let suggestion: OutfitSuggestion
    let garments: [Garment]
    let onSave: () -> Void

    @State private var saved = false

    var body: some View {
        VStack(spacing: 0) {
            if let rationale = suggestion.rationale.first {
                MonoLabel(rationale, size: 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                Divider().overlay(Theme.line)
            }

            let sorted = sortedGarments(garments)
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                GarmentStackRow(garment: garment, compact: true)
                if idx < sorted.count - 1 {
                    Theme.line.frame(height: 0.5).padding(.leading, 78)
                }
            }

            Divider().overlay(Theme.line)

            Button {
                if !saved {
                    onSave()
                    withAnimation(.drapeContent) { saved = true }
                }
            } label: {
                HStack {
                    MonoLabel(saved ? "Saved to outfits" : "Save this look",
                              size: 10, color: saved ? Theme.inkFaint : Theme.ink)
                    Spacer()
                    Image(systemName: saved ? "checkmark" : "plus")
                        .font(.caption)
                        .foregroundStyle(saved ? Theme.inkFaint : Theme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(saved)
            .sensoryFeedback(.success, trigger: saved)
        }
        .drapeCard(radius: 18)
    }
}
