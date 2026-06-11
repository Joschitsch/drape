//
//  TypewriterText.swift
//  drape
//
//  The Style tab's loading ritual: a single creative line that types itself out
//  character-by-character with a blinking cursor, in the editorial serif voice.
//  Also home to the shared `.shimmer()` skeleton sheen used by redacted
//  placeholders. Both honour Reduce Motion.
//

import SwiftUI

/// Types `text` out one character at a time with a blinking cursor, rendered
/// through `SerifText` italic. Restarts whenever `text` changes (drive that with
/// `.id(text)` at the call site). Under Reduce Motion the full line is shown at
/// once with no per-character animation.
struct TypewriterText: View {
    /// The per-character typing cadence. Exposed so callers can compute how long
    /// a given line takes to type (e.g. to hold a loading state until it finishes).
    static let charInterval: Duration = .milliseconds(45)

    /// How long `text` takes to type out fully at the default cadence.
    static func typingDuration(for text: String) -> Duration {
        charInterval * text.count
    }

    let text: String
    var size: CGFloat = 22
    var charInterval: Duration = TypewriterText.charInterval

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var visibleCount = 0
    @State private var cursorOn = true

    /// Same-width cursor: a left-half block on, a figure space off, so the line
    /// never reflows as the cursor blinks.
    private var cursor: String { cursorOn ? "\u{258F}" : "\u{2007}" }
    private var prefix: String { String(text.prefix(visibleCount)) }

    var body: some View {
        Group {
            if reduceMotion {
                SerifText(text, size: size, italic: true)
            } else {
                SerifText(prefix + cursor, size: size, italic: true)
                    .task(id: text) {
                        visibleCount = 0
                        for _ in text {
                            try? await Task.sleep(for: charInterval)
                            if Task.isCancelled { return }
                            visibleCount += 1
                        }
                    }
                    .task {
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(500))
                            cursorOn.toggle()
                        }
                    }
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityLabel(text)
    }
}

// MARK: - Shimmer (skeleton sheen)

/// A soft sheen that sweeps across a redacted placeholder to signal loading.
/// Disabled under Reduce Motion, where a static `.redacted` reads fine on its own.
struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .overlay(
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, Theme.paper.opacity(0.55), .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .rotationEffect(.degrees(18))
                        .offset(x: phase * geo.size.width * 1.4)
                        .blendMode(.plusLighter)
                    }
                    .mask(content)
                    .allowsHitTesting(false)
                )
                .task {
                    while !Task.isCancelled {
                        withAnimation(.linear(duration: 1.1)) { phase = 1 }
                        try? await Task.sleep(for: .milliseconds(1100))
                        phase = -1
                    }
                }
        }
    }
}

extension View {
    /// Sweeps a subtle sheen across a redacted placeholder. No-op under Reduce Motion.
    func shimmer() -> some View { modifier(Shimmer()) }
}

#Preview {
    VStack(spacing: 40) {
        TypewriterText(text: "Pairing things that have never met before…")
        RoundedRectangle(cornerRadius: 16)
            .fill(Theme.surface)
            .frame(height: 72)
            .redacted(reason: .placeholder)
            .shimmer()
    }
    .padding()
    .background(Theme.paper)
}
