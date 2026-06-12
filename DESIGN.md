---
name: Drape
description: Wardrobe intelligence for the morning ritual
colors:
  ink: "#1C1A17"
  ink-soft: "#6B655C"
  ink-faint: "#A8A095"
  paper: "#F6F4EF"
  surface: "#FCFBF8"
  raised: "#FFFFFF"
  ink-dark: "#F2EEE6"
  ink-soft-dark: "#A39C90"
  ink-faint-dark: "#6E675C"
  paper-dark: "#171614"
  surface-dark: "#201E1B"
  raised-dark: "#27241F"
typography:
  display:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "22px"
    fontWeight: 500
    lineHeight: 1.2
    letterSpacing: "0.01em"
  headline:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "18px"
    fontWeight: 500
    lineHeight: 1.25
    letterSpacing: "0.01em"
  title:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Hanken Grotesk, system-ui, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontFamily: "Spline Sans Mono, monospace"
    fontSize: "11px"
    fontWeight: 400
    lineHeight: 1
    letterSpacing: "0.06em"
rounded:
  button: "14px"
  card: "16px"
  card-hero: "24px"
  chip: "9999px"
spacing:
  content: "16px"
  tile: "12px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.button}"
    padding: "0px 24px"
    height: "52px"
  button-primary-disabled:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.button}"
    padding: "0px 24px"
    height: "52px"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.button}"
    padding: "0px 24px"
    height: "50px"
  chip-active:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    rounded: "{rounded.chip}"
    padding: "7px 14px"
  chip-inactive:
    backgroundColor: "transparent"
    textColor: "{colors.ink-soft}"
    rounded: "{rounded.chip}"
    padding: "7px 14px"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.card}"
    padding: "16px"
---

# Design System: Drape

## 1. Overview

**Creative North Star: "The Considered Wardrobe"**

Drape is a morning-ritual tool. Its visual system is built around a single premise: the interface should step back so the clothes can come forward. Every design decision is judged against the question "does this belong in the first 15 minutes of someone's day?" — which means clarity over cleverness, confidence over ornamentation, and warmth that comes from craft rather than decoration.

The three-family type stack — Newsreader serif for display and story lines, Hanken Grotesk for body and UI, Spline Sans Mono for kickers and captions — carries all the brand expression. Color is deliberately absent. The palette runs from near-black warm ink to warm off-white paper, adaptive to light and dark mode, with no accent color. Hierarchy is established through size, weight, and opacity alone. When the clothes appear, they are the only color.

This system explicitly rejects the clinical wardrobe-tracker aesthetic: no spreadsheet energy, no row-after-row density without warmth, no empty-state apology screens. It also rejects the gamified fitness-app aesthetic: no streak badges, no points, no progress-for-its-own-sake. The app does not shout, does not perform, and does not sell. It earns attention through restraint.

**Key Characteristics:**
- Achromatic interface — no accent color; garment colors are the only color
- Editorial serif + grotesk + mono triple-stack for a well-dressed typographic hierarchy
- Warm adaptive neutrals (light: paper/surface/raised/ink; dark: inverted counterparts)
- Flat-by-default elevation with hairline card borders; structural shadow reserved for hero photo cards only
- Swift-native motion at 150–350 ms, always with reduce-motion alternatives

## 2. Colors: The Achromatic Wardrobe

A warm near-neutral palette in two directions: deep ink and warm paper. No accent. The absence of color is the design decision.

All colors are adaptive — light-mode values are listed; dark-mode counterparts are noted. The system uses `UIColor { traits in }` resolution so every token follows the system appearance automatically.

### Primary

Drape has no primary accent color. This is intentional. See **The No-Accent Rule** below.

### Neutral

- **Warm Ink** (`ink` · #1C1A17 · dark: #F2EEE6): Near-black with a faint warm undertone. Primary text, active chip fills, button backgrounds, icon strokes. The dominant visual mass of the interface.
- **Ink Soft** (`ink-soft` · #6B655C · dark: #A39C90): Secondary text — brand names, supporting copy, placeholder text. Never used for body paragraphs that need to be read.
- **Ink Faint** (`ink-faint` · #A8A095 · dark: #6E675C): Captions and monospace labels. The floor of the readable range; below this, text is decoration.
- **Paper** (`paper` · #F6F4EF · dark: #171614): Main screen background. Warm off-white in light; near-black with a warm cast in dark. Every screen is built on this.
- **Surface** (`surface` · #FCFBF8 · dark: #201E1B): Card and section fill. One step lighter than paper in light mode, one step lighter than paper-dark in dark mode. The layering is tonal, not tinted.
- **Raised** (`raised` · #FFFFFF · dark: #27241F): The uppermost tonal layer. Selected chip backgrounds, popover surfaces. Pure white in light; deep warm in dark.

### Named Rules

**The No-Accent Rule.** There is no accent color. The interface is achromatic so that garments — the actual subject — are the only color. Adding a teal action color or a terracotta highlight is prohibited. Hierarchy is weight, size, and opacity. If a new screen needs to emphasize something, it uses `ink` at higher opacity, not a new color.

**The Warm Undertone Rule.** Every neutral is warm-biased: ink is `#1C1A17` (not `#111111`), paper is `#F6F4EF` (not `#FAFAFA`). Pure grays are forbidden. The warm cast is the brand's only color expression.

## 3. Typography: The Editorial Stack

**Display Font:** Newsreader (bundled, Medium weight · 500)
**Body Font:** Hanken Grotesk (bundled, Regular/Medium/SemiBold/Bold)
**Label Font:** Spline Sans Mono (bundled, Regular/Medium)

**Character:** The pairing works on contrast, not similarity. Newsreader is a variable optical-size serif with editorial provenance — it reads like a newspaper heading. Hanken Grotesk is a warm geometric sans. Spline Sans Mono adds a mechanical, time-stamped precision to kickers and metadata. Together they cover three distinct registers: story, system, and signal.

All sizes scale with Dynamic Type via SwiftUI's `relativeTo:` parameter. The sizes below are at the default content size; the system scales proportionally at larger accessibility sizes.

### Hierarchy

- **Display** (Newsreader Medium 500, 22–28px, leading 1.2, tracking +0.01em): Garment names, section heroes, recommendation labels ("First thought", "Wild card"), onboarding headlines. The only face that can carry a line like *"Become the version of yourself you already own the clothes for."*
- **Headline** (Newsreader Medium 500, 18px, leading 1.25): Card-level headlines, suggestion card labels, section titles that carry editorial weight.
- **Title** (Hanken Grotesk SemiBold 600, 17px, leading 1.3): Navigation titles, primary action copy inside buttons. The grotesk at its most authoritative.
- **Body** (Hanken Grotesk Regular 400, 15px, leading 1.5): Supporting copy, occasion descriptions, rationale text. Stays below 65ch line length wherever readable prose appears.
- **Label** (Spline Sans Mono Regular 400, 9–11px, UPPERCASE, tracking +0.06em): Kickers, captions, metadata — "THE MORNING RITUAL", "SAVE THIS LOOK", garment category tags. Always uppercase. Never sentence-case.

### Named Rules

**The Three-Voice Rule.** Newsreader is for story. Hanken Grotesk is for system. Spline Sans Mono is for signal. Do not assign a voice to a role that belongs to another: no Mono in headlines, no Serif in buttons, no Grotesk kickers where Mono is expected.

**The Mono-Is-Signal Rule.** MonoLabel appears on information the user needs to scan, not read — occasion tags, category labels, sub-captions. It is not a decorative style to apply to anything that needs "character." Its rarity is part of the signal.

## 4. Elevation

Drape uses a flat-by-default tonal layering system. The three surface tiers (`paper` → `surface` → `raised`) establish depth through background color alone, not shadow. Cards are distinguished from their background by being one step lighter (`surface` on `paper`) and by a 0.5pt hairline border in `Theme.line` (10% ink opacity in light, 13% paper opacity in dark).

The single exception is the GarmentCard hero: a full-bleed 3:4 photo card with a structural drop shadow (`shadow(color: black@15%, radius: 20, x: 0, y: 12)`). This shadow is earned — it lifts a large photo out of the page in a way that tonal layering cannot. It does not apply to any content card.

### Shadow Vocabulary

- **Hero Lift** (iOS: `.shadow(color: Theme.shadow, radius: 20, x: 0, y: 12)`): Structural lift for the GarmentCard photo hero. The only shadow in the system. Applied once, consistently.

### Named Rules

**The Flat-By-Default Rule.** Cards are flat at rest. Depth is tonal: `surface` (#FCFBF8) on `paper` (#F6F4EF), separated by a 0.5pt hairline in `Theme.line`. Shadows are not added to convey "this is a card." The hairline does that work.

**The One Shadow Rule.** Drop shadow appears only on `GarmentCard` — the full-bleed photo hero. No other component gets a shadow. If a new component feels like it needs depth, solve it with tonal background and border, not shadow.

## 5. Components

### Buttons

The button vocabulary is two variants: one primary, one secondary. No tertiary, no ghost, no text-only action that looks like a link. Every destructive action uses a separate contextual affordance.

- **Shape:** Continuously rounded rectangle (14px / `RoundedRectangle(cornerRadius: 14, style: .continuous)`)
- **Primary (CTAButton):** Ink fill, paper label, Hanken Grotesk SemiBold 17px, full-width, 52pt minimum height. The only full-saturation ink usage in the interface. Press feedback: `scaleEffect(0.97)` at `easeOut(0.12s)`.
- **Disabled:** Opacity 0.4 on the whole button; shape and fill unchanged.
- **Secondary (SecondaryButton):** Surface fill, ink outline at 25% opacity, ink label, full-width, 50pt minimum height. Pairs with CTAButton where two actions share a screen.
- **Circle Icon (CircleIconButton):** 44pt circle, surface fill, hairline `Theme.line` border, ink icon. Filled variant inverts to ink fill. Used for add / close / refresh actions.

### Chips

Capsule shape (`9999px` radius). Used for occasion selection, filter pills, and style tags.

- **Active:** Ink fill, paper label, Hanken Grotesk Medium 13px, `14px × 7px` padding.
- **Inactive:** Transparent fill, ink-soft label, `Theme.line` hairline border, same padding.
- **Small variant:** 12px label, `11px × 5px` padding. For compact filter rows.

### Cards / Containers

Two card types:

**Content Card (`drapeCard`):**
- Corner: 14–18px continuously rounded (varies per context; 18px on suggestion cards, 16px default)
- Background: `Theme.surface` (#FCFBF8 light / #201E1B dark)
- Border: 0.5pt `Theme.line` strokeBorder (10% ink)
- Shadow: None
- Internal padding: `16px × 13-16px` depending on content density

**GarmentCard (Hero Photo):**
- Corner: 24px continuously rounded
- Background: Full-bleed photo (3:4 aspect ratio)
- Caption: Bottom-pinned Liquid Glass strip with `MonoLabel` category + `SerifText` name + Hanken Grotesk brand
- Shadow: Hero Lift (see Elevation)
- No border

### Inputs / Fields

Form fields use iOS native `TextField` styled to match the Drape vocabulary:
- Inline within card surfaces (`drapeCard` container)
- No standalone border on the field itself — the enclosing card provides the containment
- Focus ring: iOS system focus state (not customized)
- Labels use Hanken Grotesk Medium 13px in `ink-soft`

### Navigation

- **Tab bar:** iOS native tab bar, system styling. Custom `drape.*` SF Symbol icons.
- **Navigation title:** Hanken Grotesk via `.navigationTitle()` — system rendering. Large title on list screens, inline on detail screens.
- **Back / dismiss:** System back button; `CircleIconButton` for modal dismissal.
- No custom nav chrome. The system navigation bar inherits the paper background.

### Signature Component: MonoLabel

The `MonoLabel` is Drape's brand signal at the micro scale. 11pt Spline Sans Mono, uppercase, tracking +0.06em, `ink-faint` color by default. It appears as:
- Section kickers ("THE MORNING RITUAL", "OCCASION")
- Card sub-captions (garment category, rationale phrase)
- Action labels ("SAVE THIS LOOK", "READS YOUR WEATHER, YOUR WARDROBE, AND YOUR WEEK")

It never appears as a standalone section header. It always accompanies a `SerifText` display line or a content block it introduces.

### Signature Component: TypewriterText

Used exclusively for the recommendations loading state. A single line types itself character by character at a pace tuned to the length of the copy. Reduce-motion: the full line appears instantly, then fades after a 700ms read delay. This is the one moment in the app with performative motion — it earns it because the wait is real, and the copy is tailored to the user's occasion and city.

## 6. Do's and Don'ts

### Do:
- **Do** use `Theme.ink` and `Theme.paper` (and their dark counterparts) from `Theme.swift` for all text and background values. Never hardcode hex colors.
- **Do** use Newsreader for garment names, recommendation labels, occasion headers — any line that needs to feel like an editorial statement.
- **Do** apply `MonoLabel` for kickers and captions. Uppercase, tracked, faint. Its rarity in the design makes it readable as a signal.
- **Do** use `drapeCard()` modifier for all grouped content cards: surface fill + 0.5pt hairline. This is the only card style in the product register.
- **Do** reserve the drop shadow (`GarmentCard`) for full-bleed photo heroes. If a new surface needs that shadow, confirm it's a photo-forward hero first.
- **Do** respect `@Environment(\.accessibilityReduceMotion)`: every transition has an instant-fallback path.
- **Do** use `CTAButton` for every primary action. One look, one name, everywhere. Consistency over local optimization.
- **Do** keep button and card corners continuously rounded (`style: .continuous`) — the squircle interpolation is part of the iOS-native feel.

### Don't:
- **Don't** introduce an accent color. No teal action tint, no terracotta highlight, no blue link color. The interface is achromatic; the clothes provide the only color. This is **The No-Accent Rule** — non-negotiable.
- **Don't** use pure `#111111` or `#FAFAFA` grays. Every neutral must have the warm undertone. Use the `Theme` tokens.
- **Don't** use Newsreader in buttons, labels, or nav titles. It is a story face. System UI, confirmations, and affordances speak in Hanken Grotesk.
- **Don't** use Spline Sans Mono in sentence-case or at sizes above 13px. It is a signal face — small, uppercase, tracking-forward. Scaled up or lowercased, it loses its identity and gains noise.
- **Don't** add a second, third, or decorative shadow. The One Shadow Rule applies globally.
- **Don't** nest `drapeCard` inside `drapeCard`. Nested cards are always wrong. If content needs grouping within a card, use a separator (`Theme.line` at 0.5pt) or a tonal background tier.
- **Don't** build a clinical wardrobe-tracker feel: no dense spreadsheet rows without breathing room, no cold gray system font on white, no "0 items" empty states that just report absence. Empty states teach, they don't apologize.
- **Don't** add gamification: no streak counters, no badge indicators, no progress rings for "wardrobe completeness." Drape is a considered tool, not a fitness app for your closet.
- **Don't** use the system `.borderedProminent` or `.bordered` button styles — the tint color they inherit from the app accent conflicts with the No-Accent Rule.
- **Don't** add a loading spinner in the center of content. The `TypewriterText` is the loading pattern for recommendations; skeleton/shimmer (`.redacted(reason: .placeholder)`) is the pattern for async content. Spinners are background-process indicators only.
