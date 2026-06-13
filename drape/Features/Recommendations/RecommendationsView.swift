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

    /// The typewriter loading line is showing.
    @State private var isLoading = false
    /// A search has produced results at least once — flips the CTA to "Update".
    @State private var hasSearched = false
    /// The creative line chosen for the current load. Only shown while loading,
    /// so it starts empty and is set in `search()`.
    @State private var loadingLine = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    pickerHeader

                    if isLoading {
                        TypewriterText(text: loadingLine)
                            .id(loadingLine)
                            .frame(maxWidth: .infinity, minHeight: 80, alignment: .center)
                            .padding(.top, 40)
                            .transition(.opacity)
                    } else if hasSearched {
                        resultsList
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(Theme.contentPadding)
                .animation(.snappy(duration: 0.35), value: isLoading)
                .animation(.snappy(duration: 0.35), value: hasSearched)
                .animation(.snappy(duration: 0.35), value: model.isLoadingWeather)
                .animation(.snappy(duration: 0.35), value: model.lastWeather)
            }
            .background(Theme.paper.ignoresSafeArea())
            .task { await model.loadWeather(container: container) }
            .navigationTitle("Style")
        }
    }

    // MARK: - Occasion picker (always visible)

    private var pickerHeader: some View {
        VStack(alignment: .leading, spacing: 24) {
            MonoLabel("The morning ritual")

            weatherSlot

            SerifText("Where are you headed today?", size: 22)

            SingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                              selection: Bindable(model).occasion)

            VStack(spacing: 12) {
                CTAButton(title: hasSearched ? "Update my picks" : "Find me something to wear") {
                    Task { await search() }
                }

                MonoLabel("Reads your weather, your wardrobe, and your week", size: 10)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Weather slot (strip / skeleton / omitted)

    @ViewBuilder
    private var weatherSlot: some View {
        if let weather = model.lastWeather {
            WeatherStrip(weather: weather, city: model.locationName ?? profile?.homeCity)
                .transition(.opacity)
        } else if model.isLoadingWeather {
            WeatherStrip(
                weather: WeatherSnapshot(
                    temperatureCelsius: 18,
                    apparentTemperatureCelsius: 17,
                    precipitationChance: 0.2,
                    condition: .clear
                ),
                city: "Loading"
            )
            .redacted(reason: .placeholder)
            .shimmer()
            .transition(.opacity)
            .accessibilityLabel("Loading weather")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "cloud.slash")
                    .font(.caption)
                    .foregroundStyle(Theme.inkSoft)
                Text("Weather unavailable — recommendations use your wardrobe only.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .drapeCard(radius: 14)
            .transition(.opacity)
        }
    }

    // MARK: - Results: 3 outfit suggestion cards

    @ViewBuilder
    private var resultsList: some View {
        if model.suggestions.isEmpty {
            if model.emptyReason == .nothingSuitsContext {
                ContentUnavailableView(
                    "Nothing fits the brief",
                    image: "drape.style",
                    description: Text(nothingSuitsDescription)
                )
            } else {
                ContentUnavailableView(
                    "Not enough items",
                    image: "drape.style",
                    description: Text("Add more wardrobe items — you need footwear and a top + bottom (or a dress) to get suggestions.")
                )
            }
        } else {
            let labels = ["First thought", "Second option", "Wild card"]
            VStack(alignment: .leading, spacing: 20) {
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
    }

    /// Copy for "slots covered, but every candidate was filtered". Occasions
    /// with a formality band (work, date, formal) most likely filtered on
    /// dress code; the relaxed occasions only hard-filter on warmth, so
    /// there the weather is the honest explanation.
    private var nothingSuitsDescription: String {
        if model.occasion.formalityTolerance.isFinite {
            "Your wardrobe has the pieces, but nothing fits \(model.occasion.preferencePhrase) — consider adding dressier options."
        } else {
            "Your wardrobe has the pieces, but nothing suits today's weather — consider adding something for this temperature."
        }
    }

    // MARK: - Helpers

    /// Runs a search: pick a line tuned to occasion + location, then hold the
    /// loading state until that line has fully typed (the engine is near-instant,
    /// so the typing time sets the pace), then reveal results.
    private func search() async {
        let city = model.locationName ?? profile?.homeCity
        loadingLine = StyleLoadingCopy.line(for: model.occasion, city: city)
        let start = ContinuousClock.now
        withAnimation(.snappy(duration: 0.35)) { isLoading = true }

        await model.refresh(wardrobe: wardrobe, profile: profile, container: container)

        if reduceMotion {
            try? await Task.sleep(for: .milliseconds(700))   // line shows at once; brief read
        } else {
            // Hold until the sentence finishes typing, plus a beat to read it.
            let target = TypewriterText.typingDuration(for: loadingLine) + .milliseconds(450)
            let elapsed = ContinuousClock.now - start
            if elapsed < target { try? await Task.sleep(for: target - elapsed) }
        }

        withAnimation(.snappy(duration: 0.35)) {
            isLoading = false
            hasSearched = true
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
                                    Theme.line.frame(height: 0.5).padding(.leading, 78)
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
                        .foregroundStyle(saved ? Theme.inkFaint : Theme.ink)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(saved)
        }
        .drapeCard(radius: 18)
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
                if let rationale = suggestion.rationale.first {
                    Text(rationale)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkSoft)
                }

                VStack(spacing: 0) {
                    let sorted = sortedGarments(garments)
                    ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, garment in
                        NavigationLink(value: garment) {
                            DetailGarmentRow(garment: garment)
                        }
                        .buttonStyle(.plain)
                        if idx < sorted.count - 1 {
                            Theme.line.frame(height: 0.5).padding(.leading, 96)
                        }
                    }
                }
                .drapeCard(radius: 18)
            }
            .padding(Theme.contentPadding)
        }
        .navigationTitle(label)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Garment.self) { GarmentDetailView(garment: $0) }
    }
}

#Preview {
    let container = AppContainer.preview()
    RecommendationsView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
