//
//  MoodboardCanvas.swift
//  drape
//
//  The pure collage composition: warm grainy paper + overlapping garment
//  cut-outs with soft, per-piece-varied shadows and slight rotations. Drives
//  both the live editor board (animated, with loading placeholders) and the
//  static list/recommendation thumbnails. It takes an explicit size and reads
//  images from in-memory maps (no async/environment dependency) so it renders
//  correctly inside `ImageRenderer`.
//

import SwiftUI
import UIKit

struct MoodboardCanvas: View {
    let placements: [PlacedGarment]
    /// Transparent cut-out images keyed by garment id.
    let cutouts: [UUID: UIImage]
    /// Opaque fallbacks used only after a cut-out attempt fails.
    var fallbacks: [UUID: UIImage] = [:]
    /// Garments whose cut-out is still loading — shown as a pulsing placeholder.
    var pending: Set<UUID> = []
    /// Spring pieces in as they arrive (editor) vs. render statically (thumbnails).
    var animated: Bool = false
    /// When set, each piece is tappable (read-only detail collage). The top-most
    /// piece at a point receives the tap.
    var onTapPiece: ((UUID) -> Void)? = nil
    /// Draw the paper background. Off when a parent supplies its own (thumbnail
    /// letterbox) so the composition can sit on full-frame paper.
    var showsBackground: Bool = true
    let size: CGSize

    private let warmShadow = Theme.adaptive(Color(hex: "241A12").opacity(0.22),
                                            Color.black.opacity(0.5))

    var body: some View {
        ZStack {
            if showsBackground {
                AppBackground()
            }

            // `placements` arrives sorted back→front.
            ForEach(placements) { placed in
                piece(placed)
            }

            if placements.isEmpty {
                emptyPrompt
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    @ViewBuilder
    private func piece(_ placed: PlacedGarment) -> some View {
        let boxW = placed.widthFraction * size.width
        let boxH = placed.heightFraction * size.height
        let pos = CGPoint(x: placed.center.x * size.width,
                          y: placed.center.y * size.height)

        Group {
            if let image = cutouts[placed.id] ?? fallbacks[placed.id] {
                let rad = placed.shadowAngle * .pi / 180
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: boxW, height: boxH)
                    .shadow(color: warmShadow,
                            radius: boxW * placed.shadowRadiusFraction,
                            x: CGFloat(cos(rad)) * boxW * 0.06,
                            y: CGFloat(sin(rad)) * boxW * 0.06)
                    .modifier(DropIn(animated: animated))
                    .contentShape(Rectangle())
                    .modifier(TapPiece(id: placed.id, onTap: onTapPiece))
            } else if pending.contains(placed.id) {
                PulsingPlaceholder()
                    .frame(width: boxW, height: boxH)
            }
        }
        .position(pos)
        .zIndex(placed.zIndex)
    }

    private var emptyPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "hand.tap")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.inkFaint)
            SerifText("Tap a piece to start your board", size: 18, italic: true,
                      color: Theme.inkSoft)
        }
    }
}

// MARK: - Piece tap

/// Makes a piece tappable only when a handler is provided (read-only collage);
/// otherwise the piece stays inert so the editor/thumbnails are unaffected.
///
/// A `Button` + `PressableScale` keeps the piece scroll-safe (it yields to the
/// surrounding horizontal gallery, so dragging across a cutout still scrolls the
/// rack) and accessible (a real button trait), while scaling **on press** so it
/// reads as tappable the moment you touch it — no opacity dim, one animation.
private struct TapPiece: ViewModifier {
    let id: UUID
    let onTap: ((UUID) -> Void)?

    func body(content: Content) -> some View {
        if let onTap {
            Button { onTap(id) } label: { content }
                .buttonStyle(PressableScale(scale: 0.92))
        } else {
            content
        }
    }
}

// MARK: - Piece entrance

/// Springs a piece onto the board (slight drop + scale overshoot) the first time
/// its image appears. A no-op when `animated` is false (thumbnails).
private struct DropIn: ViewModifier {
    let animated: Bool
    @State private var shown = false

    func body(content: Content) -> some View {
        let settled = shown || !animated
        content
            .scaleEffect(settled ? 1 : 0.9)
            .offset(y: settled ? 0 : -18)
            .opacity(settled ? 1 : 0)
            .onAppear {
                guard animated else { return }
                withAnimation(.interpolatingSpring(stiffness: 170, damping: 13)) {
                    shown = true
                }
            }
    }
}

// MARK: - Loading placeholder

/// A soft breathing block shown in a piece's spot while its cut-out is computed.
private struct PulsingPlaceholder: View {
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Theme.surface)
            .opacity(pulse ? 0.55 : 0.25)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 0.5)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
