//
//  CoverFlowGallery.swift
//  drape
//
//  The single, shared "flip through a physical rack" gallery used by the
//  Wardrobe, Outfits, and Style screens. One large item is centred with its
//  neighbours peeking on either side, each progressively more tilted, scaled
//  down, and faded the further it sits from centre. The tilt/scale/opacity are
//  driven continuously by the scroll position via `.scrollTransition`'s
//  `phase.value`, so the depth animates as a function of position rather than a
//  binary focused/unfocused switch.
//
//  All three galleries share this component and the one `GalleryMetrics` source
//  of truth, so changing the animation here changes every gallery at once. The
//  content is rendered completely clean — no card, border, shadow, or overlay —
//  so the flat-lay image floats directly on the app background.
//

import SwiftUI

/// The single source of truth for the cover-flow depth animation. Edit these and
/// every gallery in the app changes together.
enum GalleryMetrics {
    /// Gap between item slots.
    static let spacing: CGFloat = 10
    /// Maximum Y-axis tilt of a fully off-centre neighbour, in degrees.
    static let maxTilt: Double = 22
    /// How much a fully off-centre neighbour shrinks (1 → ~0.78).
    static let scaleDrop: CGFloat = 0.22
    /// How much a fully off-centre neighbour fades (1 → ~0.55).
    static let opacityDrop: CGFloat = 0.45
    /// 3D perspective applied to the tilt.
    static let perspective: CGFloat = 0.45
}

/// How the gallery snaps. `viewAligned` centres one item with symmetric
/// neighbours (Wardrobe, Outfits); `paging` advances one large page at a time
/// with the next peeking in (Style results).
enum GallerySnap {
    case viewAligned
    case paging
}

struct CoverFlowGallery<Item: Identifiable, Content: View>: View {
    let items: [Item]
    /// The id of the item currently snapped to centre. Reported back so callers
    /// can fade in its name/metadata *outside* the scroll view.
    @Binding var selection: Item.ID?
    var snap: GallerySnap = .viewAligned
    /// Fraction of the gallery width one item occupies. Smaller → more peek.
    var itemWidthFraction: CGFloat = 0.62

    @ViewBuilder let content: (Item) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Shown once per install: the rack gives a small swipe nudge the first time a
    /// gallery appears, so the horizontal content is discoverable without an
    /// explicit scrollbar.
    @AppStorage("hasSeenGalleryScrollHint") private var hasSeenScrollHint = false
    @State private var hintNudge: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let itemWidth = geo.size.width * itemWidthFraction
            let sideInset = max(0, (geo.size.width - itemWidth) / 2)

            ScrollView(.horizontal) {
                LazyHStack(spacing: GalleryMetrics.spacing) {
                    ForEach(items) { item in
                        card(for: item, itemWidth: itemWidth)
                    }
                }
                .scrollTargetLayout()
                .offset(x: hintNudge)
            }
            .scrollIndicators(.hidden)
            .scrollPosition(id: $selection)
            .modifier(GalleryLayout(snap: snap, sideInset: sideInset))
            .onAppear(perform: playScrollHintIfNeeded)
        }
    }

    /// A brief "settle" shimmy — the rack peeks the next item, then springs back —
    /// played at most once ever, and never under Reduce Motion.
    private func playScrollHintIfNeeded() {
        guard !hasSeenScrollHint, !reduceMotion, items.count > 1 else { return }
        hasSeenScrollHint = true
        withAnimation(.easeInOut(duration: 0.4).delay(0.5)) { hintNudge = -34 }
        withAnimation(.interpolatingSpring(stiffness: 150, damping: 14).delay(0.9)) { hintNudge = 0 }
    }

    @ViewBuilder
    private func card(for item: Item, itemWidth: CGFloat) -> some View {
        // Capture the animation inputs into Sendable locals so the scroll
        // transition closure doesn't reach back into main-actor state.
        let reduceMotion = reduceMotion
        let maxTilt = GalleryMetrics.maxTilt
        let scaleDrop = GalleryMetrics.scaleDrop
        let opacityDrop = GalleryMetrics.opacityDrop
        let perspective = GalleryMetrics.perspective

        content(item)
            .modifier(GalleryItemWidth(snap: snap, itemWidth: itemWidth))
            .frame(maxHeight: .infinity)
            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .rotation3DEffect(
                        .degrees(reduceMotion ? 0 : phase.value * maxTilt),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .center,
                        perspective: perspective
                    )
                    .scaleEffect(reduceMotion ? 1 : 1 - abs(phase.value) * scaleDrop)
                    .opacity(reduceMotion ? 1 : 1 - abs(phase.value) * opacityDrop)
            }
            .id(item.id)
    }
}

// MARK: - Snap + peek layout

/// Sizes a single item for the chosen snap mode: a fixed fraction for the
/// centred cover-flow, or the full container width for paging (peek comes from
/// the scroll content margins).
private struct GalleryItemWidth: ViewModifier {
    let snap: GallerySnap
    let itemWidth: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch snap {
        case .viewAligned:
            content.frame(width: itemWidth)
        case .paging:
            content.containerRelativeFrame(.horizontal)
        }
    }
}

/// Applies the matching snap behaviour and the centring inset / peek margin.
private struct GalleryLayout: ViewModifier {
    let snap: GallerySnap
    let sideInset: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        switch snap {
        case .viewAligned:
            content
                .safeAreaPadding(.horizontal, sideInset)
                .scrollTargetBehavior(.viewAligned)
        case .paging:
            content
                .contentMargins(.horizontal, sideInset, for: .scrollContent)
                .scrollTargetBehavior(.paging)
        }
    }
}
