//
//  StyleThisPieceView.swift
//  drape
//
//  "Style this piece": locks one garment and asks the engine to build outfits
//  around it. Reuses the whole rule-based engine via RecommendationContext's
//  lockedGarmentID — no new scoring, just a constrained candidate set.
//
//  Results render with the same editorial language as the Style tab
//  (RecommendationsView): a cover-flow of full outfit collages, page dots,
//  a styling line, and a save/feedback row — kept in lockstep with that view.
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

    /// The look snapped to centre in the cover-flow.
    @State private var carouselFocus: Int? = nil
    /// Tapping a garment in a collage opens its detail.
    @State private var tappedGarment: Garment? = nil

    /// Per-look control state, keyed by look index and reset on each search.
    @State private var savedPages: Set<Int> = []
    @State private var feedbackDonePages: Set<Int> = []
    @State private var reasonsForPage: Int? = nil

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                    .padding(.horizontal, Theme.contentPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 14)

                content
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationTitle("Style this piece")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $tappedGarment) { GarmentDetailView(garment: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
            .task(id: occasion) { await run() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonoLabel("Building looks around")
            SerifText(garment.displayName, size: 22)

            SingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                              selection: $occasion)
        }
    }

    // MARK: - Content (calm prompt / light loading / results)

    @ViewBuilder
    private var content: some View {
        if isLoading && results.isEmpty {
            loadingPlaceholder
        } else if results.isEmpty {
            emptyResults
        } else {
            resultsBody
        }
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 10) {
            Spacer()
            SerifText("Pulling looks together", size: 20)
                .multilineTextAlignment(.center)
                .redacted(reason: .placeholder)
                .shimmer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Theme.contentPadding)
        .transition(.opacity)
    }

    private var emptyResults: some View {
        ContentUnavailableView(
            "No looks yet",
            image: "drape.style",
            description: Text("Couldn't build an outfit around this piece for \(occasion.displayName.lowercased()). Try another occasion or add more items."))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsBody: some View {
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
        .opacity(isLoading ? 0.35 : 1)
        .onAppear { syncCarouselFocus() }
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
        return HStack(spacing: 12) {
            PrimaryActionButton(
                title: saved ? "Saved" : "Save look",
                systemImage: saved ? "bookmark.fill" : "bookmark"
            ) {
                guard !saved else { return }
                save(page.garments)
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
        if let profile {
            profile.applyFeedback(reasons: reasons, positive: positive)
            modelContext.insert(OutfitFeedback(
                positive: positive, reasons: reasons,
                garmentIDs: page.suggestion.garmentIDs, occasion: occasion))
            try? modelContext.save()
        }
        withAnimation(.drapeContent) {
            _ = feedbackDonePages.insert(page.id)
            reasonsForPage = nil
        }
    }

    // MARK: - Pages

    /// One look in the curated set; `id` is its index.
    private struct SuggestionPage: Identifiable {
        let id: Int
        let suggestion: OutfitSuggestion
        let garments: [Garment]
    }

    private var pages: [SuggestionPage] {
        results.enumerated().map { idx, item in
            SuggestionPage(id: idx, suggestion: item.suggestion, garments: item.garments)
        }
    }

    private func syncCarouselFocus() {
        if carouselFocus == nil || !pages.contains(where: { $0.id == carouselFocus }) {
            carouselFocus = pages.first?.id
        }
    }

    // MARK: - Run

    private func run() async {
        // Fresh set → reset focus + per-look control state.
        savedPages = []
        feedbackDonePages = []
        reasonsForPage = nil
        carouselFocus = nil

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

        carouselFocus = pages.first?.id
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
