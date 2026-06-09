//
//  DrapeControls.swift
//  drape
//
//  The shared control vocabulary, so every screen draws the same cards,
//  buttons, swatches and tags instead of re-implementing them inline. All
//  styling flows through the adaptive `Theme` tokens, so these are correct in
//  both light and dark and meet the 44pt minimum hit target.
//

import SwiftUI

// MARK: - Card

/// The surface + hairline-border + rounded-rectangle treatment used by every
/// grouped card in the app. Apply with `.drapeCard()`.
struct DrapeCard: ViewModifier {
    var radius: CGFloat = 16
    var fill: Color = Theme.surface

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 0.5)
            )
    }
}

extension View {
    /// Wraps the view in the standard Drape card (surface fill + 0.5pt hairline).
    func drapeCard(radius: CGFloat = 16, fill: Color = Theme.surface) -> some View {
        modifier(DrapeCard(radius: radius, fill: fill))
    }
}

// MARK: - Primary CTA

/// The primary action pill — ink fill, paper label, full width. Used for every
/// "I wore this today" / "Find me something" / "Add to wardrobe" / paywall CTA.
struct CTAButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.body(17, weight: .semibold))
                .foregroundStyle(Theme.paper)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .scaleEffect(pressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: pressed)
        ._onPressGesture { pressed = $0 }
    }
}

// MARK: - Circular icon button

/// A 44pt circular icon button — surface fill, hairline border, ink glyph. The
/// shared chrome for add / close / refresh / back actions.
struct CircleIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var filled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(filled ? Theme.paper : Theme.ink)
                .frame(width: 44, height: 44)
                .background(filled ? Theme.ink : Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: filled ? 0 : 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Color swatch button

/// A selectable color swatch with a full 44pt hit area. The visible disc stays
/// compact; selection is shown by an ink ring with a paper gap.
struct SwatchButton: View {
    let colorTag: ColorTag
    var isSelected: Bool = false
    var diameter: CGFloat = 28
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(colorTag.color)
                .frame(width: diameter, height: diameter)
                .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
                .overlay {
                    if isSelected {
                        Circle()
                            .strokeBorder(Theme.ink, lineWidth: 2)
                            .padding(-4)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorTag.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Icon label style

/// Consistent icon↔title spacing for labels that carry a leading glyph. The
/// custom `drape.*` symbols have no side bearing, so a default `Label` renders
/// them flush against the text; this gives every icon-label a uniform gap and a
/// fixed icon column so rows line up.
struct DrapeIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .frame(width: 24, alignment: .center)
            configuration.title
        }
    }
}

extension LabelStyle where Self == DrapeIconLabelStyle {
    /// Uniform icon-to-text spacing for labels with a leading symbol.
    static var drapeIcon: DrapeIconLabelStyle { .init() }
}

// MARK: - Sticky footer

/// The bottom CTA chrome shared by detail screens: a short paper gradient that
/// fades the scrolling content out, then the action(s) on a solid paper base
/// above the home indicator.
struct StickyFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.paper.opacity(0), Theme.paper],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 28)
            content
                .padding(.horizontal, Theme.contentPadding)
                .padding(.bottom, 24)
                .background(Theme.paper)
        }
    }
}

// MARK: - Press gesture helper

private struct PressGesture: ViewModifier {
    let onPress: (Bool) -> Void
    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in onPress(true) }
                .onEnded { _ in onPress(false) }
        )
    }
}

extension View {
    fileprivate func _onPressGesture(_ onPress: @escaping (Bool) -> Void) -> some View {
        modifier(PressGesture(onPress: onPress))
    }
}
