//
//  RecommendationsView.swift
//  drape
//
//  One inline screen. A pinned occasion filter sits above a cover-flow of floating
//  outfit collages (the same shared gallery + visual language as the Outfits tab).
//  Nothing runs until you pick an occasion; tapping a chip is the opt-in. Each pick
//  fetches a small curated set you swipe through, with a short styling line per look.
//  Switching occasion re-generates in place with a light crossfade.
//

import SwiftUI
import SwiftData
import UIKit

struct RecommendationsView: View {
    @Query(filter: #Predicate<Garment> { !$0.isArchived })
    private var wardrobe: [Garment]

    @Query private var profiles: [UserProfile]
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    @State private var model = RecommendationsViewModel()

    /// A generation is in flight — a light in-place loading treatment.
    @State private var isGenerating = false
    /// Looks have been produced at least once — collapses the weather, lights the
    /// chosen occasion chip. Never resets: the pinned chips stay live, so there is
    /// no dead-end to escape.
    @State private var hasGenerated = false

    /// The look snapped to centre in the cover-flow.
    @State private var carouselFocus: Int? = nil
    /// Tapping a garment in a collage opens its detail.
    @State private var tappedGarment: Garment? = nil
    /// Presenting the location picker — plan looks for somewhere other than here.
    @State private var showingLocationPicker = false

    /// Per-look control state, keyed by look index and reset on each search.
    @State private var savedPages: Set<Int> = []
    @State private var feedbackDonePages: Set<Int> = []
    @State private var reasonsForPage: Int? = nil

    private var profile: UserProfile? { profiles.first }

    /// The saved home location as a pickable place, offered as a quick row in the
    /// location picker when coordinates are stored.
    private var homePlace: PlaceSuggestion? {
        guard let profile, let lat = profile.homeLatitude, let lon = profile.homeLongitude
        else { return nil }
        let name = (profile.homeCity?.isEmpty == false) ? profile.homeCity! : "Home"
        return PlaceSuggestion(name: name, coordinate: Coordinate(latitude: lat, longitude: lon))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.contentPadding)
                    .padding(.top, 8)
                    .padding(.bottom, hasGenerated ? 14 : 0)

                content
            }
            .background(AppBackground().ignoresSafeArea())
            .task { await model.loadWeather(container: container) }
            .navigationTitle("Style")
            .navigationDestination(item: $tappedGarment) { GarmentDetailView(garment: $0) }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerSheet(
                    planned: model.plannedPlace,
                    home: homePlace,
                    onSelect: { selection in
                        Task {
                            await model.selectPlace(selection, container: container)
                            // Re-rank against the new location's weather if looks
                            // are already on screen.
                            if hasGenerated { await generate() }
                        }
                    }
                )
                .environment(container)
            }
            .animation(.snappy(duration: 0.35), value: hasGenerated)
            .animation(.snappy(duration: 0.35), value: isGenerating)
            .animation(.snappy(duration: 0.35), value: model.isLoadingWeather)
            .animation(.snappy(duration: 0.35), value: model.lastWeather)
        }
    }

    // MARK: - Header (collapses in place once results exist)

    private var header: some View {
        VStack(alignment: .leading, spacing: hasGenerated ? 12 : 18) {
            if hasGenerated {
                // Collapsed: the brief on the left doubles as the way back to the
                // occasion picker; the same location control on the right.
                HStack(alignment: .center, spacing: 8) {
                    backToPickerButton
                    Spacer(minLength: 8)
                    locationButton
                }
            } else {
                // Idle: the location control sits above the weather widget.
                VStack(alignment: .leading, spacing: 10) {
                    locationButton
                    weatherSlot
                }
            }

            // The single control, shown once looks exist so the resting state's
            // invitation is the occasion cards below rather than a flat chip row.
            // Nothing is lit until the first pick.
            if hasGenerated {
                OptionalSingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                                          selection: occasionFilter)
            }
        }
    }

    /// The one consistent location control, shown in both the idle and collapsed
    /// headers so "change location" reads the same everywhere.
    private var locationButton: some View {
        LocationButton(
            name: model.activeLocationName ?? profile?.homeCity,
            isPlanning: model.plannedPlace != nil,
            action: { showingLocationPicker = true }
        )
    }

    /// Collapsed-state context: what the picks are responding to — occasion and
    /// weather (when known). Location lives in `locationButton` beside it.
    private var contextKicker: some View {
        var parts = [model.occasion.displayName]
        if let w = model.lastWeather {
            parts.append("\(w.condition.displayName) \(Int(w.temperatureCelsius))°")
        }
        return MonoLabel(parts.joined(separator: " · "), size: 10)
            .lineLimit(1)
    }

    /// The single trigger and filter. Nothing is lit until the first pick; picking
    /// an occasion (first time or a switch) re-generates in place. Re-tapping the
    /// active chip (which `OptionalSingleChoiceChips` reports as a deselect) is a
    /// no-op.
    private var occasionFilter: Binding<Occasion?> {
        Binding(
            get: { hasGenerated ? model.occasion : nil },
            set: { newValue in
                guard let newValue else { return }
                let changed = newValue != model.occasion
                model.occasion = newValue
                if !hasGenerated || changed {
                    Task { await generate() }
                }
            }
        )
    }

    // MARK: - Content (calm prompt / light loading / results)

    @ViewBuilder
    private var content: some View {
        if isGenerating && model.suggestions.isEmpty {
            // No prior looks to dim (first run, or switching from an empty
            // occasion) — show the placeholder rather than flashing the empty state.
            loadingPlaceholder
        } else if hasGenerated {
            resultsBody
        } else {
            occasionPicker
        }
    }

    /// The resting state: a browsable set of occasion cards. Nothing runs until
    /// one is tapped — the card *is* the opt-in, the same trigger the chips are
    /// once looks exist. Fills the space with a tactile invitation rather than a
    /// void.
    private var occasionPicker: some View {
        let columns = [GridItem(.flexible(), spacing: Theme.tileSpacing),
                       GridItem(.flexible(), spacing: Theme.tileSpacing)]
        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                MonoLabel("Today's looks", size: 10)
                SerifText("Where are you headed today?", size: 22)
            }

            LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                ForEach(Occasion.allCases) { occasion in
                    occasionCard(occasion)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, Theme.contentPadding)
        .padding(.top, 8)
        .transition(.opacity)
    }

    private func occasionCard(_ occasion: Occasion) -> some View {
        Button {
            pick(occasion)
        } label: {
            VStack(spacing: 8) {
                Image(occasion.iconName)
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.ink)
                SerifText(occasion.displayName, size: 18)
                MonoLabel(tagline(for: occasion), size: 9)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .padding(.horizontal, 12)
            .drapeCard(radius: 16)
        }
        .buttonStyle(PressableScale(scale: 0.96))
        .accessibilityLabel(occasion.displayName)
        .accessibilityHint("See today's looks for \(occasion.preferencePhrase)")
    }

    /// Kicks off the first generation from an occasion card. Mirrors the
    /// `occasionFilter` set-closure: set the occasion, then generate in place.
    private func pick(_ occasion: Occasion) {
        model.occasion = occasion
        Task { await generate() }
    }

    /// A short editorial subline per occasion — dry, never cringe, echoing the
    /// voice of the loading copy. View-local so the domain `Occasion` stays lean.
    private func tagline(for occasion: Occasion) -> String {
        switch occasion {
        case .everyday: "Out and about"
        case .work:     "Quietly capable"
        case .date:     "Worth a second glance"
        case .sport:    "Ready to sweat"
        case .formal:   "Cloth-napkin ready"
        case .travel:   "Layers, one plane"
        }
    }

    /// A brief in-place placeholder shown while the engine runs and there are no
    /// prior looks to dim — the very first generation, or switching from an empty
    /// occasion. When prior looks exist, `resultsBody` dims them instead.
    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            SerifText("Pulling today's looks together", size: 20)
                .multilineTextAlignment(.center)
                .redacted(reason: .placeholder)
                .shimmer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.contentPadding)
        .transition(.opacity)
    }

    @ViewBuilder
    private var resultsBody: some View {
        if model.suggestions.isEmpty {
            emptyResults
        } else {
            VStack(spacing: 0) {
                CoverFlowGallery(items: pages, selection: $carouselFocus, itemWidthFraction: 0.6) { page in
                    collage(page)
                }
                .frame(maxHeight: .infinity)

                if pages.count > 1 {
                    pageDots.padding(.bottom, 10)
                }

                lookBlock
            }
            .opacity(isGenerating ? 0.35 : 1)
            .onAppear { syncCarouselFocus() }
        }
    }

    private func collage(_ page: SuggestionPage) -> some View {
        MoodboardThumbnail(
            garments: page.garments,
            useFullResolution: true,
            onTapPiece: { tappedGarment = $0 },
            showsBackground: false,
            fillsContent: true
        )
        .padding(.vertical, 4)
        // A soft contact shadow so the look feels placed, not adrift (not a card).
        .background(alignment: .bottom) {
            Ellipse()
                .fill(Theme.ink.opacity(0.06))
                .frame(height: 16)
                .blur(radius: 12)
                .padding(.horizontal, 56)
                .padding(.bottom, 10)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(pages) { page in
                Circle()
                    .fill(page.id == focusedID ? Theme.ink : Theme.inkFaint.opacity(0.35))
                    .frame(width: 6, height: 6)
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.drapeContent, value: focusedID)
    }

    // MARK: - Look block: voice (index + rationale) + balanced actions

    private var focusedID: Int? { carouselFocus ?? pages.first?.id }

    private var focusedPage: SuggestionPage? {
        guard let focusedID else { return pages.first }
        return pages.first { $0.id == focusedID } ?? pages.first
    }

    @ViewBuilder
    private var lookBlock: some View {
        if let page = focusedPage {
            VStack(spacing: 14) {
                voice(page)
                    .id(page.id)
                    .transition(.opacity)

                actionRow(page)

                if feedbackDonePages.contains(page.id) {
                    feedbackConfirmation
                } else if reasonsForPage == page.id {
                    reasonsRow(page)
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.top, 2)
            .padding(.bottom, 14)
            .animation(.drapeContent, value: carouselFocus)
        }
    }

    private func voice(_ page: SuggestionPage) -> some View {
        VStack(spacing: 5) {
            MonoLabel("Look \(page.id + 1) of \(pages.count)", size: 9)
            if let line = stylingLine(page.suggestion) {
                SerifText(line, size: 18, italic: true)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// The first rationale that isn't the redundant warmth line.
    private func stylingLine(_ suggestion: OutfitSuggestion) -> String? {
        suggestion.rationale.first {
            !$0.hasPrefix("Right warmth") && !$0.hasPrefix("May be too")
        }
    }

    private func actionRow(_ page: SuggestionPage) -> some View {
        let done = feedbackDonePages.contains(page.id)
        let saved = savedPages.contains(page.id)
        // Save is the primary — a prominent pill that flexes to fill the row.
        // The thumbs are subordinate icon buttons beside it; once feedback is
        // given they fall away and only Save remains.
        return HStack(spacing: 12) {
            PrimaryActionButton(
                title: saved ? "Saved" : "Save look",
                systemImage: saved ? "bookmark.fill" : "bookmark"
            ) {
                guard !saved else { return }
                save(page.suggestion, garments: page.garments)
                withAnimation(.drapeContent) { _ = savedPages.insert(page.id) }
            }
            .sensoryFeedback(.success, trigger: saved)

            if !done {
                CircleIconButton(systemName: "hand.thumbsup", accessibilityLabel: "Good pick") {
                    sendFeedback(page, positive: true, reasons: [])
                }
                CircleIconButton(systemName: "hand.thumbsdown", accessibilityLabel: "Not for me") {
                    withAnimation(.drapeContent) {
                        reasonsForPage = (reasonsForPage == page.id) ? nil : page.id
                    }
                }
            }
        }
    }

    private func reasonsRow(_ page: SuggestionPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel("What felt off?", size: 10)
            FlowLayout(spacing: 6) {
                ForEach(FeedbackReason.allCases) { reason in
                    DrapeChip(label: reason.displayName, active: false) {
                        sendFeedback(page, positive: false, reasons: [reason])
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    /// A quiet acknowledgement shown after thumbs feedback, so the controls don't
    /// just silently vanish.
    private var feedbackConfirmation: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
            MonoLabel("Noted — tuning your looks", size: 10)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .transition(.opacity)
    }

    private func sendFeedback(_ page: SuggestionPage, positive: Bool, reasons: [FeedbackReason]) {
        model.submitFeedback(
            positive: positive, reasons: reasons,
            suggestion: page.suggestion, profile: profile, context: modelContext)
        withAnimation(.drapeContent) {
            _ = feedbackDonePages.insert(page.id)
            reasonsForPage = nil
        }
    }

    // MARK: - Empty / pages

    @ViewBuilder
    private var emptyResults: some View {
        Group {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One look in the curated set; `id` is its index.
    private struct SuggestionPage: Identifiable {
        let id: Int
        let suggestion: OutfitSuggestion
        let garments: [Garment]
    }

    /// The curated set the user swipes through (up to five).
    private var pages: [SuggestionPage] {
        model.suggestions.prefix(5).enumerated().map { idx, item in
            SuggestionPage(id: idx, suggestion: item.suggestion, garments: item.garments)
        }
    }

    private func syncCarouselFocus() {
        if carouselFocus == nil || !pages.contains(where: { $0.id == carouselFocus }) {
            carouselFocus = pages.first?.id
        }
    }

    /// Copy for "slots covered, but every candidate was filtered".
    private var nothingSuitsDescription: String {
        if model.occasion.formalityTolerance.isFinite {
            "Your wardrobe has the pieces, but nothing fits \(model.occasion.preferencePhrase) — consider adding dressier options."
        } else {
            "Your wardrobe has the pieces, but nothing suits today's weather — consider adding something for this temperature."
        }
    }

    // MARK: - Weather slot (full strip / skeleton / omitted — idle header)

    @ViewBuilder
    private var weatherSlot: some View {
        if let weather = model.lastWeather {
            WeatherStrip(weather: weather)
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
                Image(systemName: "icloud.slash")
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

    // MARK: - Generate

    /// Fetches a fresh curated set for the current occasion with a light in-place
    /// transition: the first generation crossfades from the prompt; later switches
    /// dim the existing looks (`resultsBody`) then crossfade to the new set.
    private func generate() async {
        // Fresh set → reset focus + per-look control state.
        savedPages = []
        feedbackDonePages = []
        reasonsForPage = nil
        carouselFocus = nil

        withAnimation(.drapeContent) { isGenerating = true }
        await model.refresh(wardrobe: wardrobe, profile: profile, container: container)
        withAnimation(.drapeContent) {
            isGenerating = false
            hasGenerated = true
        }

        carouselFocus = pages.first?.id
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

#Preview {
    let container = AppContainer.preview()
    RecommendationsView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
