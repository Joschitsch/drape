//
//  Typography.swift
//  drape
//
//  The two editorial text primitives that recur across every screen, mirroring
//  the design prototype's `<Mono>` and `<Serif>` components:
//    • MonoLabel  — uppercase, letter-spaced Spline Sans Mono kicker/caption.
//    • SerifText  — Newsreader display, used for titles, names and story lines.
//

import SwiftUI

/// Uppercase, letter-spaced monospace label — the kickers and captions.
struct MonoLabel: View {
    let text: String
    var size: CGFloat = 11
    var color: Color = Theme.inkFaint
    var tracking: CGFloat = 0.6

    init(_ text: String, size: CGFloat = 11, color: Color = Theme.inkFaint, tracking: CGFloat = 0.6) {
        self.text = text
        self.size = size
        self.color = color
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased())
            .font(Theme.mono(size))
            .tracking(tracking)
            .foregroundStyle(color)
    }
}

/// Pill filter/selection chip. Ink-filled when active, hairline-bordered when
/// not — the design's `Chip`.
struct DrapeChip: View {
    let label: String
    var active: Bool = false
    var small: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.body(small ? 12 : 13, weight: .medium))
                .padding(.horizontal, small ? 11 : 14)
                .padding(.vertical, small ? 5 : 7)
                .foregroundStyle(active ? Theme.paper : Theme.inkSoft)
                .background(active ? Theme.ink : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(active ? Theme.ink : Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Newsreader serif display text. Defaults to the medium optical weight the
/// design uses; pass `italic` for story / celebration lines.
struct SerifText: View {
    let text: String
    var size: CGFloat
    var italic: Bool = false
    var color: Color = Theme.ink

    init(_ text: String, size: CGFloat, italic: Bool = false, color: Color = Theme.ink) {
        self.text = text
        self.size = size
        self.italic = italic
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(Theme.serif(size, italic: italic))
            .tracking(0.1)
            .foregroundStyle(color)
    }
}
