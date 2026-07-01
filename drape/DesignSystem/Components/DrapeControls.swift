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

// MARK: - Button fills (shared by buttons and non-Button controls like PhotosPicker)

extension View {
    /// Primary pill fill — ink background, paper label. Visible in both modes.
    func drapePrimaryFill() -> some View {
        self
            .font(Theme.body(17, weight: .semibold))
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// Secondary pill fill — ink outline + ink label on surface.
    func drapeSecondaryFill() -> some View {
        self
            .font(Theme.body(17, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1)
            )
    }
}

// MARK: - Primary CTA

/// The primary action pill — ink fill, paper label, full width. Used for every
/// "I wore this today" / "Find me something" / "Add to wardrobe" / paywall CTA.
struct CTAButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Text(title)
                .contentTransition(.opacity)
                .drapePrimaryFill()
        }
        .buttonStyle(PressableScale(scale: 0.97))
        .opacity(enabled ? 1 : 0.4)
        .disabled(!enabled)
        .animation(.drapeContent, value: title)
        // A light confirmation on every primary action — the ritual taps
        // ("Find me something", "I wore this today", "Add to wardrobe").
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

// MARK: - Secondary button

/// The secondary action — ink outline + ink label on paper. Pairs with
/// `CTAButton` so non-primary actions share one consistent look (and stay
/// visible in both light and dark, unlike `.borderedProminent` under the ink
/// tint).
struct SecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
            }
            .drapeSecondaryFill()
        }
        .buttonStyle(PressableScale())
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

// MARK: - Primary action (row-sharing)

/// The primary action for a panel's action bar — ink fill, paper label, optional
/// leading glyph — that **flexes to fill** the row it shares with a secondary
/// icon and an overflow menu. The row-sharing sibling of `CTAButton` (which stays
/// full-bleed for sticky footers). One prominent CTA per panel; everything else
/// is visually subordinate.
struct PrimaryActionButton: View {
    let title: String
    var systemImage: String? = nil
    var isLoading: Bool = false
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Theme.paper)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(Theme.body(17, weight: .semibold))
                    .contentTransition(.opacity)
            }
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(PressableScale(scale: 0.97))
        .disabled(isLoading)
        .animation(.drapeContent, value: title)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

// MARK: - Circular icon button

/// A 44pt circular icon button — surface fill, hairline border, ink glyph. The
/// shared chrome for add / close / refresh / back actions.
struct CircleIconButton: View {
    let systemName: String
    var accessibilityLabel: String
    var filled: Bool = false
    /// When true the glyph is replaced by a spinner and the button is disabled —
    /// used to acknowledge async work (e.g. rendering a collage to share).
    var isLoading: Bool = false
    let action: () -> Void

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(filled ? Theme.paper : Theme.ink)
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(filled ? Theme.paper : Theme.ink)
                }
            }
            .frame(width: 44, height: 44)
            .background(filled ? Theme.ink : Theme.surface, in: Circle())
            .overlay(Circle().strokeBorder(Theme.line, lineWidth: filled ? 0 : 1))
            .contentShape(Circle())
        }
        .buttonStyle(PressableScale())
        .disabled(isLoading)
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.impact(weight: .light), trigger: tapCount)
    }
}

// MARK: - Circular overflow menu

/// A `Menu` wrapped in the exact 44pt circular chrome of `CircleIconButton`, so
/// an overflow ("⋯") menu sits in an action row looking identical to the other
/// icon buttons. Use it to contain management/destructive actions (Edit, Delete)
/// so they stay subordinate to the panel's primary action.
struct CircleMenuButton<MenuItems: View>: View {
    var systemName: String = "ellipsis"
    var accessibilityLabel: String
    @ViewBuilder var menuItems: () -> MenuItems

    var body: some View {
        Menu {
            menuItems()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.ink)
                .frame(width: 44, height: 44)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                .contentShape(Circle())
        }
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

    @State private var tapCount = 0

    var body: some View {
        Button {
            tapCount += 1
            action()
        } label: {
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
        .buttonStyle(PressableScale())
        .accessibilityLabel(colorTag.displayName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .sensoryFeedback(.selection, trigger: tapCount)
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

// MARK: - Horizontal scroll edge fade

extension View {
    /// Softly fades the leading & trailing edges of a horizontally-scrolling row
    /// so it's visually obvious there's more content to swipe to. Masks alpha
    /// (background-agnostic), so it works over the textured app background and
    /// doesn't affect hit-testing.
    func horizontalScrollFade(_ width: CGFloat = 16) -> some View {
        mask {
            GeometryReader { geo in
                let f = width / max(geo.size.width, 1)
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: f),
                        .init(color: .black, location: 1 - f),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            }
        }
    }
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

// MARK: - Press feedback (shared)

/// The one press-scale `ButtonStyle` for the whole app — a small depress pulse on
/// touch that makes every tappable control feel tactile. Like `GalleryMetrics`
/// and the `Theme` motion tokens, this is the single source of truth: tune the
/// scale here and every button in the app changes together.
///
/// Use on anything built on `Button`. For tap-gesture tiles/rows that aren't a
/// `Button`, use the `.pressable()` modifier instead.
struct PressableScale: ButtonStyle {
    /// Resting → pressed scale. Default suits buttons; pass `0.94` for large tiles.
    var scale: CGFloat = 0.96

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.drapePress, value: configuration.isPressed)
    }
}

/// Press-scale feedback for tappable surfaces that use `.onTapGesture` rather
/// than a `Button` (grid tiles, collage pieces, rows). Mirrors `PressableScale`
/// so the whole app depresses with the same rhythm.
private struct PressableModifier: ViewModifier {
    var scale: CGFloat
    @State private var pressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(pressed ? scale : 1)
            .animation(.drapePress, value: pressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in pressed = false }
            )
    }
}

extension View {
    /// Adds the shared press-scale feedback to a non-`Button` tappable surface.
    func pressable(scale: CGFloat = 0.96) -> some View {
        modifier(PressableModifier(scale: scale))
    }
}
