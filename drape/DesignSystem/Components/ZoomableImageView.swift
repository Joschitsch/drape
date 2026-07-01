//
//  ZoomableImageView.swift
//  drape
//
//  A full-screen, dismissible image viewer for inspecting a garment photo up
//  close. Pinch to zoom, drag to pan while zoomed, double-tap to toggle, and
//  swipe down (or the close button) to dismiss. Presented as a fullScreenCover
//  over a dimmed backdrop so the photo is the only thing in view.
//

import SwiftUI

struct ZoomableImageView: View {
    let assetID: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Committed zoom/offset, plus the live gesture deltas layered on top.
    @State private var scale: CGFloat = 1
    @GestureState private var gestureScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var gestureOffset: CGSize = .zero

    // Vertical pull used for swipe-to-dismiss when at rest (scale == 1).
    @State private var dragDownProgress: CGFloat = 0

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 4

    private var liveScale: CGFloat { scale * gestureScale }

    var body: some View {
        // Hosted in a NavigationStack purely so the dismiss control can be a
        // toolbar `Button(role: .close)` — the same leading circular-X system
        // control used on every other dismissable screen (GarmentDetailView,
        // PaywallView, StyleThisPieceView). The close role only renders the
        // system glyph inside a toolbar, so the viewer provides one.
        NavigationStack {
            ZStack {
                AppBackground()
                    .ignoresSafeArea()

                NormalizedImageView(assetID: assetID, useThumbnail: false)
                    .scaleEffect(liveScale)
                    .offset(x: offset.width + gestureOffset.width,
                            y: offset.height + gestureOffset.height + dragDownProgress)
                    .gesture(magnification)
                    .simultaneousGesture(panOrDismiss)
                    .onTapGesture(count: 2) { toggleZoom() }
            }
            .contentShape(Rectangle())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) { dismiss() }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel("Garment photo, enlarged")
            .accessibilityAction(.escape) { dismiss() }
        }
    }

    // MARK: - Gestures

    private var magnification: some Gesture {
        MagnificationGesture()
            .updating($gestureScale) { value, state, _ in state = value }
            .onEnded { value in
                let resolved = min(max(scale * value, minScale), maxScale)
                applyAnimated {
                    scale = resolved
                    if resolved <= minScale { offset = .zero }
                }
            }
    }

    // While zoomed, a drag pans the photo. At rest, a downward drag dismisses.
    private var panOrDismiss: some Gesture {
        DragGesture()
            .updating($gestureOffset) { value, state, _ in
                if scale > minScale { state = value.translation }
            }
            .onChanged { value in
                // Only treat a downward drag as a dismiss pull when at rest AND
                // not mid-pinch — gestureScale stays 1 unless a magnification is
                // live, so the two-finger centroid can't masquerade as a swipe.
                if scale <= minScale && gestureScale == 1 {
                    dragDownProgress = max(0, value.translation.height)
                }
            }
            .onEnded { value in
                if scale <= minScale {
                    // dragDownProgress is only ever set when not pinching, so a
                    // pinch that happens to drift down can't trip the dismiss.
                    if dragDownProgress > 120 {
                        dismiss()
                    } else {
                        applyAnimated { dragDownProgress = 0 }
                    }
                } else {
                    applyAnimated { offset.width += value.translation.width
                                    offset.height += value.translation.height }
                }
            }
    }

    private func toggleZoom() {
        applyAnimated {
            if scale > minScale {
                scale = minScale
                offset = .zero
            } else {
                scale = 2.5
            }
        }
    }

    private func applyAnimated(_ change: () -> Void) {
        if reduceMotion {
            change()
        } else {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { change() }
        }
    }
}
