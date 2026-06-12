# Product

## Register

product

## Users

Two overlapping users, each dominant on different surfaces:

- **Style-curious everyday person** (Recommendations tab, onboarding): owns good clothes but struggles to assemble outfits consistently. Wants low-friction, confident guidance — not fashion school. They hire Drape to answer "what do I wear today?"
- **Intentional dresser** (Wardrobe tab, Outfits tab): already thinks about dress but wants a system. Tracks, archives, squeezes more from what they own. They hire Drape to make their wardrobe feel coherent and well-used.

Both users share one context: a morning ritual. The app meets them when they're not yet fully awake and need a clear answer, not a project.

## Product Purpose

Drape is a wardrobe intelligence tool. It reads the user's clothes, the weather, and their occasion preferences, then makes a confident outfit recommendation. Its success looks like: the user opens the app, gets a suggestion that feels right, gets dressed, and closes the app. No deliberation. No friction.

Secondary success: the wardrobe tab makes the user feel good about what they own — not guilty about gaps, not overwhelmed by choices.

## Brand Personality

Quiet, Considered, Editorial.

A well-dressed friend with good taste who never lectures. Calm confidence. The New Yorker energy, not Vogue. Like Concepts or Day One — the product belongs to the user, feels personal, and has no service-layer agenda behind its UX.

Voice: direct but warm. Uses the occasion ("where are you headed today?") not the feature ("select your occasion"). Editorializes lightly ("First thought", "Wild card") without being precious.

## Anti-references

- **Clinical wardrobe tracker**: not a cold spreadsheet with clothes in it. Avoids lifeless minimalism; must have warmth and personality even on data-heavy screens.
- Gamified / streaky apps (Duolingo model): no badge soup, no streaks, no points.
- Fast-fashion e-commerce: not a shopping funnel. Never "you might also like."
- Trendy SaaS dashboards: not navy-and-teal gradients, not metric cards, not B2B analytics that happen to be about clothes.

## Design Principles

1. **The morning ritual standard** — every interaction is judged against "is this the right speed and weight for someone in the first 15 minutes of their day?" Clarity and confidence over comprehensiveness.
2. **The wardrobe belongs to the user** — like Concepts or Day One, the product is a personal tool, not a service. No upsell energy seeps into the core UX; the paywall surface is isolated.
3. **Editorial restraint** — typography and layout carry the brand. Decoration is earned, not default. If removing an element doesn't hurt comprehension or warmth, remove it.
4. **Warmth is not fluff** — the opposite of clinical is not decorative. Warmth comes from voice, from the serif face, from thoughtful empty states — not from gradients or rounded everything.
5. **System respect** — Dynamic Type, VoiceOver, reduce-motion. The user already has a phone; honor its contracts.

## Accessibility & Inclusion

iOS system accessibility baseline: Dynamic Type scaling at all text sizes, VoiceOver semantic labels, and `@Environment(\.accessibilityReduceMotion)` gates on all transitions (already wired into RecommendationsView). No explicit WCAG level target beyond what iOS AA compliance implies.
