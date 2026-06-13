# Drape — Engineering & Product Context

> A single-file, detailed orientation for anyone (human or agent) picking up the
> Drape codebase. Pairs with [`PRODUCT.md`](PRODUCT.md) (the why) and
> [`DESIGN.md`](DESIGN.md) (the visual system). This document is the *how it's
> built*.

---

## 1. What Drape is

Drape is a **native iOS wardrobe-intelligence app**. The user photographs the
clothes they own; Drape normalizes and classifies each item, then — reading the
wardrobe, the live weather, and the user's occasion preferences — makes a
**confident outfit recommendation** for the day. It also lets the user build and
save outfits, log what they wore, and (on Pro) see wardrobe analytics like
cost-per-wear.

The product is framed around the **morning ritual**: open the app, get a
suggestion that feels right, get dressed, close the app. No deliberation, no
friction. The brand register is *quiet, considered, editorial* — "a well-dressed
friend with good taste who never lectures." See [`PRODUCT.md`](PRODUCT.md) for the
full positioning, users, and anti-references.

**Platform / stack at a glance**

| | |
|---|---|
| Language | Swift 5 (`SWIFT_VERSION = 5.0`) |
| UI | SwiftUI |
| Persistence | SwiftData (`@Model`, on-disk SQLite) |
| Concurrency | Swift Concurrency (`async`/`await`, `@MainActor`, `Sendable`) |
| Observation | `@Observable` (Observation framework, not `ObservableObject`) |
| On-device ML | Vision (`VNClassifyImageRequest`, foreground-instance mask) |
| Weather | Open-Meteo public API (free, no key) |
| Location | CoreLocation |
| Min iOS | 26.5 (`IPHONEOS_DEPLOYMENT_TARGET = 26.5`) |
| Bundle id | `de.joschaaxthammer.drape` |
| Version | 1.0 (pre-release) |
| Tests | Swift Testing, app-hosted `drapeTests` target |

---

## 2. Architecture

### 2.1 Layering

The codebase is organized into clean layers, with **domain logic isolated behind
protocols** so concrete implementations (real vs. stub/mock) can be swapped
without touching call sites.

```
drape/
├── App/              Composition root, SwiftData container, RootView (tab shell)
├── Domain/
│   ├── Enums/        Value vocabularies (GarmentCategory, Occasion, …)
│   ├── Values/       Sendable value types (snapshots, contexts, suggestions)
│   ├── Models/       SwiftData @Model classes (Garment, Outfit, …)
│   └── Services/     PROTOCOLS only (WeatherService, RecommendationEngine, …)
├── Services/         Concrete implementations of the Domain/Services protocols
│   ├── Recommendation/  RuleBased…, Stub…, Scorers
│   ├── Classification/  Vision…, Heuristic…, Stub…
│   ├── Image/           VisionImageProcessing…, FileImageStore, in-memory/passthrough
│   ├── Weather/         OpenMeteo…, Mock…
│   ├── Location/        CoreLocation…, Stub…
│   └── Entitlement/     MockEntitlementService
├── Features/         SwiftUI views + @Observable view models, one folder per tab/flow
├── DesignSystem/     Theme, Typography, reusable components (cards, chips, dials…)
├── Resources/        Bundled fonts (Newsreader, Hanken Grotesk, Spline Sans Mono)
├── Assets.xcassets/  Custom drape.* SF Symbols (derived from Phosphor Icons)
└── Support/          PreviewData (demo seeding), PreviewData helpers
```

### 2.2 Dependency injection — `AppContainer`

[`App/AppContainer.swift`](drape/App/AppContainer.swift) is the **composition
root**. It's an `@MainActor @Observable` class holding every service behind its
protocol, injected into the SwiftUI environment.

- `AppContainer.live()` — production wiring: `VisionImageProcessingService`,
  `FileImageStore`, `VisionGarmentClassifier`, `OpenMeteoWeatherService`,
  `CoreLocationProvider`, `RuleBasedRecommendationEngine`, `MockEntitlementService`.
- `AppContainer.preview(tier:)` — deterministic, in-memory wiring for previews and
  tests: passthrough/in-memory/stub/mock variants.

Views read it with `@Environment(AppContainer.self)`. The **one** service kept as
its concrete type (not behind a protocol) is `entitlements: MockEntitlementService`,
because SwiftUI needs to observe live tier changes for feature gating; it's
injected separately via `.environment(appContainer.entitlements)`.

### 2.3 App entry & persistence

- [`drapeApp.swift`](drape/drapeApp.swift) — `@main`. On init it registers the
  bundled fonts (`DrapeFonts.registerAll()`) and creates the SwiftData
  `ModelContainer` via `.drape()`. Injects `appContainer` + `entitlements` into the
  environment.
- [`App/ModelContainer+Drape.swift`](drape/App/ModelContainer+Drape.swift) — the
  schema is **the single source of truth** for persisted types: `Garment`,
  `Outfit`, `WearEvent`, `UserProfile`. If the on-disk store is incompatible and
  SwiftData can't auto-migrate, it **resets the local store** rather than crashing
  (acceptable pre-release; production would ship a `SchemaMigrationPlan`). Demo
  data reseeds on next launch.
- [`App/RootView.swift`](drape/App/RootView.swift) — the `TabView` shell with four
  tabs: **Style** (recommendations), **Wardrobe**, **Outfits**, **Profile**. Seeds
  a profile + demo content on first launch via `PreviewData.ensureProfile`,
  backfills images, and presents onboarding as a `fullScreenCover` when
  `hasCompletedOnboarding == false`. Tint is `Theme.ink`; Dynamic Type is clamped
  to `…accessibility2`.

---

## 3. Domain model

### 3.1 SwiftData models (`Domain/Models/`)

All four are `@Model final class` with `UUID` ids (stable identity independent of
SwiftData's `PersistentIdentifier`, useful for diffing / future sync).

- **`Garment`** — one wardrobe item. **Image bytes are NOT stored here** — only
  `imageAssetID` / `thumbnailAssetID` strings that `ImageStore` resolves to files
  on disk (keeps the store lean). Holds `category`, optional `subcategory`,
  `primaryColor` + `secondaryColors` (+ optional `customColorHex` for exact display
  while `primaryColor` keeps a named family for the engine), `formality`, `warmth`,
  `seasons`, `styles`, `name`/`brand`/`notes`, optional `purchasePrice` (drives
  cost-per-wear), `isFavorite`, `isArchived` (kept for history but hidden from grid
  & excluded from recommendations). Many-to-many to `Outfit`, one-to-many to
  `WearEvent`. `wearCount` is derived.
- **`Outfit`** — a named combination of garments (many-to-many). Has an `occasion`
  and optional `notes`. `wearCount` derived from its `WearEvent`s.
- **`WearEvent`** — a log that an outfit and/or a set of garments was worn on a
  `date`, with an optional `temperatureCelsius` snapshot. Delete rule is the
  default *nullify* — wear history survives deletion of the garment/outfit it
  referenced. Feeds recency-aware recommendations and cost-per-wear.
- **`UserProfile`** — the single user's preferences (seeded once on first launch).
  Holds `preferredStyles` + `customStyles`, per-occasion `occasionPreferences`,
  `hasCompletedOnboarding`, and home location (`homeLatitude/Longitude/City`).
  **Subscription tier is intentionally NOT stored here** — it lives behind
  `EntitlementService` so the source can change (mock → StoreKit).

### 3.2 Enums (`Domain/Enums/`) — the vocabulary

- **`GarmentCategory`** — `top, bottom, dress, footwear, outerwear, accessory`. Maps
  to an **`OutfitSlot`** (`top, bottom, fullBody, footwear, outerwear, accessory`);
  a `dress` fills the combined `fullBody` slot. Each carries a `drape.*` icon name.
- **`FootwearSubcategory`** — `athletic, sandal, loafer, dress, boot`. Used to
  enforce e.g. "Sport requires athletic footwear."
- **`Formality`** (`Int`, `Comparable`) — `casual(0), smartCasual(1), business(2),
  formal(3)`.
- **`WarmthLevel`** (`Int`, `Comparable`) — `light(0), medium(1), warm(2),
  veryWarm(3)`. Each maps to a **comfortable temperature range** in °C (e.g. light
  = comfortable 18°C and up; veryWarm = up to 10°C) which the warmth scorer reads.
- **`Occasion`** — `everyday, work, date, sport, formal, travel`. Each carries a
  `displayName`, `preferencePhrase` ("a date", "the gym"), icon, a
  **`targetFormality`**, and a **`formalityTolerance`** (everyday/sport/travel =
  `.infinity` → show everything; date/work = ±1.5 levels; formal = tight).
- **`ColorTag`** — **16 named fashion hues** (ecru, ivory, oat, camel, tobacco,
  chocolate, charcoal, ink, sage, forest, denim, navy, rust, burgundy, mauve,
  slate), each with a `hex` and a coarse **`ColorFamily`** (`neutral / warm / cool`)
  used for harmony heuristics. Includes `nearest(red:green:blue:)` for mapping a
  sampled dominant color to the closest tag. ⚠️ See migration gotcha below.
- **`Season`** — `spring, summer, autumn, winter`.
- **`Style`** — not an enum of cases but a helper namespace: `normalize` (trim +
  lowercase for storage/dedup), `displayName`, and `options(custom:)` merging
  built-ins with user-added styles.
- **`SubscriptionTier`** — `free, pro`. `free` has a `garmentLimit` of **30**; `pro`
  is unlimited. **`ProFeature`** enumerates the gated features: `weeklyOutfitPlan,
  capsuleSuggestions, wardrobeAnalytics, advancedRecommendations`.

### 3.3 Value types (`Domain/Values/`)

`Sendable` structs that decouple the engine and services from SwiftData reference
types (so they can run off the main actor and be unit-tested without a
`ModelContext`):

- **`GarmentSnapshot`** — immutable projection of a `Garment`'s
  recommendation-relevant fields. `Garment.snapshot` builds it.
- **`RecommendationContext`** — the complete, self-contained engine input:
  `wardrobe` snapshots, `occasion`, optional `weather`, `profile` preferences,
  `recentWears` (`[UUID: Date]`), `desiredCount`.
- **`ProfilePreferences`** — the subset of `UserProfile` the engine reads.
- **`OutfitSuggestion`** — one scored proposal: `garmentIDs`, `score` (0…1),
  `rationale` (human-readable reasons shown in the UI).
- Others: `WeatherSnapshot`, `Coordinate`, `OccasionPreference`, `ProcessedImage`,
  `ClassificationSuggestion`.

---

## 4. The recommendation engine

The brain of the app. Defined by the
[`RecommendationEngine`](drape/Domain/Services/RecommendationEngine.swift) protocol
(`func recommend(_:) async -> [OutfitSuggestion]`), so a Core ML or LLM-backed
version can slot in later without touching the UI. The MVP is
[`RuleBasedRecommendationEngine`](drape/Services/Recommendation/RuleBasedRecommendationEngine.swift)
— deliberately **transparent and rules-based**.

### 4.1 Pipeline

1. **Candidate generation** (`buildCandidates`) — enumerates valid combinations:
   `(top, bottom, footwear)` with optional outerwear, plus `(dress, footwear)` with
   optional outerwear. Capped/shuffled to **200 candidates** to stay tractable on
   large wardrobes.
2. **Hard filters** (reject the candidate outright):
   - *Warmth*: if weather is present and the warmth score is 0, drop it (never
     recommend a temperature-wrong outfit).
   - *Formality band*: **every core garment** (excluding accessory & outerwear)
     must individually sit within the occasion's `formalityTolerance` of the target
     — no averaging, so one too-casual piece can't hide behind dressier companions.
     A user's per-occasion preference moves the target but never widens the
     tolerance.
   - *Sport footwear*: `.sport` rejects any outfit with non-athletic footwear
     (untagged footwear passes — conservative).
3. **Weighted scoring** — six composable scorers (`Scorers.swift`), each returning
   `(score: 0…1, rationale: String?)`, combined with weights then normalized:

   | Scorer | Weight | What it rewards |
   |---|---|---|
   | `scoreWarmth` | 1.5 | Outfit warmth matching apparent temp. Asymmetric fade — underdressing penalized fast (5°C window), overdressing slowly (8°C). |
   | `scoreFormality` | 1.5 | Core garments close to the occasion/user target formality. |
   | `scoreColorHarmony` | 1.0 | All-neutral (1.0), accent+neutrals (0.9), monochrome (0.85), mixed warm+cool without neutral anchor (0.5). |
   | `scoreStyleMatch` | 1.0 | Overlap between garment styles and user preferred + occasion-specific styles. |
   | `scoreRecency` | 0.8 | Penalizes recently-worn garments (full penalty at 0 days → none beyond 14). |
   | `scoreRainReadiness` | 0.6 | Bonus for outerwear when wet; strong penalty for no cover in rain. |

4. **Rank & return** — sort by score desc, take `desiredCount`, map to
   `OutfitSuggestion` (carrying the collected rationale strings).

### 4.2 Empty-state distinction

[`RecommendationsViewModel`](drape/Features/Recommendations/RecommendationsViewModel.swift)
distinguishes two empty results with `EmptyReason`:
- `.missingSlots` — the wardrobe can't form *any* outfit (no footwear, or no
  top+bottom pair and no dress).
- `.nothingSuitsContext` — outfits were possible but every candidate failed the
  occasion/weather hard filters.

This drives different, instructive empty-state copy (never a bare "0 items").

---

## 5. Services (the swappable seams)

Every external concern is a protocol in `Domain/Services/` with a real and a
stub/mock implementation in `Services/`:

| Protocol | Live impl | Test/preview impl | Notes |
|---|---|---|---|
| `RecommendationEngine` | `RuleBasedRecommendationEngine` | `StubRecommendationEngine` | §4 |
| `GarmentClassifier` | `VisionGarmentClassifier` | `Heuristic…`, `Stub…` | On-device Vision: `VNClassifyImageRequest` for category + foreground-instance mask so the dominant-color sample only reads garment pixels, not the composited canvas. Best-effort, non-throwing, returns `.empty` when unsure. Small jewellery classifies poorly. |
| `ImageProcessingService` | `VisionImageProcessingService` | `Passthrough…` | Cuts subject from background, composites onto a neutral canvas, makes a thumbnail. Input is raw `Data` (no UIKit in the protocol). |
| `ImageStore` | `FileImageStore` | `InMemoryImageStore` | Writes image + thumbnail to Application Support; returns `ImageAssetReference` ids saved on `Garment`. Could back onto a CDN later. |
| `WeatherService` | `OpenMeteoWeatherService` | `MockWeatherService` | Open-Meteo public API — **free, no key, no account** (a deliberate cost constraint). Fetches current temp, apparent temp, precipitation probability, weather code. |
| `LocationProvider` | `CoreLocationProvider` | `StubLocationProvider` | Returns a domain `Coordinate` (callers never import CoreLocation); best-effort reverse-geocode for the weather strip place name. |
| `EntitlementService` | `MockEntitlementService` | same (with `tier:`) | `@Observable`; tier persisted to `UserDefaults` (`mockEntitlementTier`). Default impls: `canAddGarment` (free cap 30), `isEnabled` (Pro = all). Real StoreKit 2 slots in behind the same protocol. |

---

## 6. Features (UI)

Each feature folder holds SwiftUI views plus an `@MainActor @Observable` view
model where there's real logic. ~3,900 LOC across `Features/`.

- **Recommendations / "Style" tab** —
  [`RecommendationsView`](drape/Features/Recommendations/RecommendationsView.swift):
  occasion picker → typewriter loading state → up to 3 outfit suggestions with
  refresh. Loads weather on appear; the CTA flips from "Find" to "Update" after the
  first search. Respects `accessibilityReduceMotion`. The
  [`TypewriterText`](drape/DesignSystem/Components/TypewriterText.swift) loading
  line is tailored to the user's occasion + city (copy in `StyleLoadingCopy.swift`)
  — the one piece of performative motion, earned because the wait is real.
- **Wardrobe tab** — `WardrobeListView` (grid with context menu + filter sheet),
  `AddGarmentView` + `AddGarmentViewModel` (the **capture → normalize → classify →
  save** flow, including an auto-generated name), `EditGarmentView`,
  `GarmentDetailView`, `GarmentFilter`/`GarmentFilterSheet`, `GarmentDraft`,
  `CameraPicker`, `GarmentAttributeFields`.
- **Outfits tab** — `OutfitListView`, `OutfitBuilderView` +
  `OutfitBuilderViewModel` (assemble one garment per slot; a dress `fullBody`
  selection is mutually exclusive with top/bottom; supports edit-existing),
  `OutfitDetailView`, `GarmentPickerSheet`.
- **Profile tab** — `ProfileView`, `WardrobeAnalyticsView` (Pro: cost-per-wear,
  rarely-used items).
- **Onboarding** — `OnboardingView` + `OnboardingViewModel`: a welcome step, one
  step per occasion (`everyday, work, date, formal`) to set target formality +
  styles, and a global-styles step. Presented as a full-screen cover until
  completed. (Still system-styled — noted as remaining polish.)
- **Paywall** — `PaywallView` (isolated upsell surface; per the product principle
  no upsell energy seeps into the core UX).
- **Shared** — `WoreTodayCelebration`, `OccasionPreferenceEditor`, `Deletion`.

---

## 7. Design system (`DesignSystem/`)

The brand is carried almost entirely by **typography and an achromatic palette** —
see [`DESIGN.md`](DESIGN.md) for the full spec. Key facts an engineer needs:

- **Three-family type stack**, all bundled under `Resources/Fonts/` and registered
  at runtime in `DrapeFonts.registerAll()` (no `UIAppFonts` plist entry):
  **Newsreader** (serif — story / display / garment names), **Hanken Grotesk** (sans
  — body & UI), **Spline Sans Mono** (mono — uppercase kickers/captions/labels).
  Use the `Theme.serif/body/mono` accessors and the `SerifText` / `MonoLabel` /
  `DrapeChip` primitives — never system fonts. *Newsreader's PostScript names are
  oddly `Newsreader16pt16pt-*`.*
- **No accent color.** The palette runs warm-ink → warm-paper, adaptive to
  light/dark via `UIColor { traits in }`. Garment photos are the only color.
  Hierarchy = size, weight, opacity. Never hardcode hex — use `Theme` tokens.
- **Flat by default.** Tonal layering (`paper → surface → raised`) + 0.5pt hairline
  borders. The *only* shadow in the app is the `GarmentCard` photo hero.
- Reusable components live in `DesignSystem/Components/` (cards, chips, dials,
  flow layout, weather strip, typewriter, selectable chip rows, etc.).
- Custom `drape.*` SF Symbols in `Assets.xcassets` are derived from **Phosphor
  Icons** (MIT) — see [`Resources/IconLicense.md`](drape/Resources/IconLicense.md).

---

## 8. Building, running, testing

⚠️ **`xcode-select -p` points at the CommandLineTools**, so bare `xcodebuild`
fails. Set `DEVELOPER_DIR` inline (Xcode 26.5 at `/Applications/Xcode.app`):

```bash
# Build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project drape.xcodeproj -scheme drape \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Unit tests (Swift Testing, app-hosted target)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild test \
  -project drape.xcodeproj -scheme drape \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:drapeTests
```

The project uses **file-system-synchronized groups** (`objectVersion 77`), so new
files added under `drape/` (and `drapeTests/`) compile automatically — **no
`project.pbxproj` edits needed**.

An **XcodeBuildMCP** server is configured in [`.mcp.json`](.mcp.json) (simulator +
ui-automation workflows) for build/run/screenshot automation.

### Tests (`drapeTests/`, Swift Testing)

Golden-scenario coverage of the engine and its empty-state logic:
- `EngineBehaviorTests` — overall ranking behavior
- `FormalityGoldenTests` — formality-band hard filter
- `FootwearGoldenTests` — sport athletic-footwear rule
- `WeatherGoldenTests` — warmth scoring vs. temperature
- `EmptyReasonTests` — `.missingSlots` vs. `.nothingSuitsContext`
- `Support/Fixtures.swift` — shared test garments/contexts

---

## 9. Gotchas & constraints (read before changing things)

- **SwiftData enum-migration trap.** Changing `ColorTag` (or any `@Model` enum's)
  raw values **crashes existing stores** — the property getter traps when decoding
  an unknown value. After such a change, wipe the sim container
  (`xcrun simctl uninstall … && install`) so `PreviewData.seed` reseeds fresh. The
  live app self-heals by resetting the store (§2.3) and reseeding demo data on
  first launch via `ensureProfile`.
- **Cost constraint.** Early-stage: avoid a paid Apple Developer account and paid
  services. Hence Open-Meteo (free, no key) for weather and `MockEntitlementService`
  instead of real StoreKit. Keep new dependencies free.
- **Images never live in SwiftData.** Only asset-id strings; bytes go through
  `ImageStore` to disk. Don't put `Data`/`UIImage` on a `@Model`.
- **Engine purity.** The recommendation engine operates on `Sendable` snapshots and
  must stay free of SwiftData reference types and the main actor, so it stays
  testable and swappable.
- **No accent color, ever.** The achromatic rule is non-negotiable (`DESIGN.md`).
  Don't reach for `.borderedProminent`/`.tint` accents; use `Theme` tokens.
- **Pre-release schema.** No `SchemaMigrationPlan` yet — the container resets on
  incompatible schema. Add one before shipping real user data.

---

## 10. Pointers

| Topic | File |
|---|---|
| Product positioning, users, voice | [`PRODUCT.md`](PRODUCT.md) |
| Visual system, tokens, components | [`DESIGN.md`](DESIGN.md) |
| Composition root / DI | [`drape/App/AppContainer.swift`](drape/App/AppContainer.swift) |
| Schema & store recovery | [`drape/App/ModelContainer+Drape.swift`](drape/App/ModelContainer+Drape.swift) |
| Tab shell & seeding | [`drape/App/RootView.swift`](drape/App/RootView.swift) |
| Recommendation logic | [`drape/Services/Recommendation/`](drape/Services/Recommendation/) |
| Scorers | [`drape/Services/Recommendation/Scorers.swift`](drape/Services/Recommendation/Scorers.swift) |
| Demo data seeding | [`drape/Support/PreviewData.swift`](drape/Support/PreviewData.swift) |
| Design critiques (impeccable skill) | [`.impeccable/critique/`](.impeccable/critique/) |
