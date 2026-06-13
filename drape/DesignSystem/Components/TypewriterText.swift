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
    /// Cursor visibility. Held solid (1) while typing, then blinks once the line
    /// finishes. The cursor glyph is always laid out, so toggling its opacity
    /// never reflows the text.
    @State private var cursorOpacity: Double = 1

    private var prefix: String { String(text.prefix(visibleCount)) }

    /// The typed prefix plus an always-present, opacity-toggled cursor. Built as a
    /// `Text` concatenation (matching `SerifText`'s styling) so the cursor keeps a
    /// constant width and the tail never jitters as it blinks.
    private var typedLine: Text {
        let typed = Text(prefix).font(Theme.serif(size, italic: true))
        let cursor = Text("\u{258F}")
            .font(Theme.serif(size, italic: true))
            .foregroundColor(Theme.ink.opacity(cursorOpacity))
        return Text("\(typed)\(cursor)")
    }

    var body: some View {
        Group {
            if reduceMotion {
                SerifText(text, size: size, italic: true)
            } else {
                typedLine
                    .tracking(0.1)
                    .foregroundStyle(Theme.ink)
                    .lineSpacing(size >= 20 ? 3 : 2)
                    .task(id: text) {
                        // Type the line out, cursor solid throughout…
                        cursorOpacity = 1
                        visibleCount = 0
                        for _ in text {
                            try? await Task.sleep(for: charInterval)
                            if Task.isCancelled { return }
                            visibleCount += 1
                        }
                        // …then settle into a calm, steady blink.
                        while !Task.isCancelled {
                            try? await Task.sleep(for: .milliseconds(500))
                            cursorOpacity = cursorOpacity == 1 ? 0 : 1
                        }
                    }
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityLabel(text)
        // A soft keystroke tick as each visible glyph lands. Whitespace is silent
        // so it reads as typing, not a buzz; no-op under Reduce Motion.
        .sensoryFeedback(trigger: visibleCount) { _, newValue in
            guard !reduceMotion, newValue > 0, newValue <= text.count else { return nil }
            let idx = text.index(text.startIndex, offsetBy: newValue - 1)
            return text[idx].isWhitespace ? nil : .impact(weight: .light, intensity: 0.35)
        }
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
