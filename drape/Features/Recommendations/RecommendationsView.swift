//
//  RecommendationsView.swift
//  drape
//
//  "The Occasion Ritual" — idle occasion picker → loading state → 3 consistent
//  outfit suggestions with refresh. Visual language matches the Outfits tab.
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
    @State private var loadingPhase: LoadingPhase = .idle

    private var profile: UserProfile? { profiles.first }

    enum LoadingPhase { case idle, loading, results }

    var body: some View {
        NavigationStack {
            ZStack {
                switch loadingPhase {
                case .idle:    idleView
                case .loading: loadingView
                case .results: resultsView
                }
            }
            .navigationTitle("Style")
            .toolbar {
                if case .results = loadingPhase {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            Task { await refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Idle: occasion picker

    private var idleView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                MonoLabel("The morning ritual")

                // Weather strip (if available)
                if let weather = model.lastWeather {
                    WeatherStrip(weather: weather, city: profile?.homeCity)
                }

                // Headline
                SerifText("Where are you headed today?", size: 22)

                // Occasion chips
                FlowLayout(spacing: 9) {
                    ForEach(Occasion.allCases) { occasion in
                        DrapeChip(label: occasion.displayName,
                                  active: model.occasion == occasion) {
                            model.occasion = occasion
                        }
                    }
                }

                // CTA
                VStack(spacing: 12) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        Text("Find me something to wear")
                            .font(Theme.body(17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.ink)
                            .foregroundStyle(Theme.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    MonoLabel("Reads your weather, your wardrobe, and your week", size: 10)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.contentPadding)
        }
    }

    // MARK: - Loading: animated ring + cycling text

    private var loadingView: some View {
        LoadingRitualView(occasionName: model.occasion.displayName,
                          cityName: model.lastWeather != nil ? "your location" : nil)
    }

    // MARK: - Results: 3 outfit suggestion cards

    private var resultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ← Change occasion link
                Button {
                    loadingPhase = .idle
                } label: {
                    Label("Change occasion", systemImage: "chevron.left")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                }
                .buttonStyle(.plain)

                // Suggestion cards
                if model.suggestions.isEmpty {
                    ContentUnavailableView(
                        "Not enough items",
                        systemImage: "tshirt",
                        description: Text("Add more wardrobe items — you need footwear and a top + bottom (or a dress) to get suggestions.")
                    )
                } else {
                    let labels = ["First thought", "Second option", "Wild card"]
                    ForEach(Array(model.suggestions.prefix(3).enumerated()), id: \.offset) { idx, item in
                        OutfitSuggestionCard(
                            label: idx < labels.count ? labels[idx] : "#\(idx + 1)",
                            suggestion: item.suggestion,
                            garments: item.garments,
                            onSave: { save(item.suggestion, garments: item.garments) }
                        )
                    }
                }
            }
            .padding(Theme.contentPadding)
        }
    }

    // MARK: - Helpers

    private func refresh() async {
        loadingPhase = .loading
        await model.refresh(wardrobe: wardrobe, profile: profile, container: container)
        loadingPhase = .results
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

// MARK: - Suggestion card (consistent with OutfitStackCard)

private struct OutfitSuggestionCard: View {
    let label: String
    let suggestion: OutfitSuggestion
    let garments: [Garment]
    let onSave: () -> Void

    @State private var saved = false
    @State private var showDetail = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Tappable body → outfit detail ────────────────────────
            Button { showDetail = true } label: {
                VStack(spacing: 0) {
                    // Header: label + rationale
                    VStack(alignment: .leading, spacing: 5) {
                        SerifText(label, size: 18)
                        if let rationale = suggestion.rationale.first {
                            MonoLabel(rationale, size: 9)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)

                    Divider().overlay(Theme.line)

                    // Garment rows
                    let sorted = sortedGarments(garments)
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                        GarmentStackRow(garment: garment, compact: true)
                        if idx < sorted.count - 1 {
                            HStack { Color.clear.frame(height: 0) }
                                .overlay(alignment: .leading) {
                                    Theme.line.frame(height: 0.5).padding(.leading, 68)
                                }
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.line)

            // ── Save footer ──────────────────────────────────────────
            Button {
                if !saved {
                    onSave()
                    saved = true
                }
            } label: {
                HStack {
                    MonoLabel(saved ? "Saved to outfits" : "Save this look",
                              size: 10, color: saved ? Theme.inkFaint : Theme.ink)
                    Spacer()
                    Image(systemName: saved ? "checkmark" : "plus")
                        .font(.caption)
                        .foregroundStyle(saved ? Theme.inkFaint : .primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }
            .buttonStyle(.plain)
            .disabled(saved)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.5))
        .navigationDestination(isPresented: $showDetail) {
            SuggestionDetailView(garments: garments, suggestion: suggestion, label: label)
        }
    }
}

// MARK: - Suggestion detail (reuses OutfitDetailView layout without SwiftData model)

private struct SuggestionDetailView: View {
    let garments: [Garment]
    let suggestion: OutfitSuggestion
    let label: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    if let rationale = suggestion.rationale.first {
                        Text(rationale)
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSoft)
                    }
                }

                VStack(spacing: 0) {
                    let sorted = sortedGarments(garments)
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                        NavigationLink(value: garment) {
                            DetailGarmentRow(garment: garment)
                        }
                        .buttonStyle(.plain)
                        if idx < sorted.count - 1 {
                            HStack { Color.clear.frame(height: 0) }
                                .overlay(alignment: .leading) {
                                    Theme.line.frame(height: 0.5).padding(.leading, 96)
                                }
                        }
                    }
                }
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.line, lineWidth: 0.5))
            }
            .padding(Theme.contentPadding)
        }
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
    }
}

// MARK: - DetailGarmentRow (also used in OutfitDetailView, redeclared here for access)
// NOTE: this duplicates the private struct in OutfitDetailView; extract to shared file if needed.
private struct DetailGarmentRow: View {
    let garment: Garment
    var body: some View {
        HStack(spacing: 14) {
            NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category, colorTag: garment.primaryColor)
                .frame(width: 66, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
            VStack(alignment: .leading, spacing: 4) {
                MonoLabel(garment.category.displayName, size: 8.5)
                SerifText(garment.displayName, size: 16).lineLimit(1)
                if let brand = garment.brand, !brand.isEmpty {
                    Text(brand).font(Theme.body(12.5)).foregroundStyle(Theme.inkSoft)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                Circle().fill(garment.primaryColor.color).frame(width: 14, height: 14)
                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.inkFaint)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(minHeight: 56)
    }
}

// MARK: - Loading ritual

private struct LoadingRitualView: View {
    let occasionName: String
    let cityName: String?

    private var lines: [String] {
        [
            "Checking the sky\(cityName.map { " over \($0)" } ?? "")…",
            "Pulling pieces that fit \(occasionName.lowercased())…",
            "Noticing what you've been neglecting…",
        ]
    }

    @State private var lineIndex = 0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            // Spinner ring
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(.primary.opacity(0.15), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            // Cycling italic text
            SerifText(lines[lineIndex], size: 22, italic: true)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280, minHeight: 60, alignment: .top)
                .id(lineIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { t in
                withAnimation(.easeInOut(duration: 0.3)) {
                    lineIndex = (lineIndex + 1) % lines.count
                }
                if lineIndex == lines.count - 1 { t.invalidate() }
            }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    RecommendationsView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
