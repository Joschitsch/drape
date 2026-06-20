//
//  GroundTruthRecord.swift
//  drape
//
//  DEBUG-ONLY. The ground-truth review tool's value types. A `GroundTruthRecord`
//  pairs the pipeline's auto-filled attributes for a real garment with the human
//  ground-truth judgment, keyed by `Garment.id`. These live entirely separate
//  from the `Garment` model — nothing here is ever written back onto it — so the
//  production data model is untouched (see DebugGroundTruthView / GroundTruthStore).
//
//  `AttributeSnapshot` holds typed optionals so the review pickers bind directly,
//  while `AttributeSnapshot.axes` projects each axis to a readable string token for
//  divergence checks, the agreement summary and the CSV/JSON export — mirroring the
//  per-axis shape of `AttributeEval`.
//

#if DEBUG
import Foundation

/// A garment's attributes across every auto-filled axis. Used for both the
/// pipeline's `auto` values and the human `truth` values, so the two are directly
/// comparable. All fields optional: the engine treats nil as "not committed", and
/// truth can legitimately be left unset.
struct AttributeSnapshot: Codable, Equatable, Sendable {
    var category: GarmentCategory?
    var footwearSubcategory: FootwearSubcategory?
    var primaryColor: ColorTag?
    var formality: Formality?
    var warmth: WarmthLevel?
    var seasons: [Season] = []
    var fit: Fit?
    var topLength: TopLength?
    var bottomVolume: BottomVolume?
    var structure: Structure?
    var fabricWeight: FabricWeight?
    var patternType: PatternType?
    var patternScale: PatternScale?
    var texture: Texture?
    var archetype: Archetype?

    init() {}

    /// Captures the pipeline's current auto-filled values off a real garment.
    init(auto g: Garment) {
        category = g.category
        footwearSubcategory = g.subcategory.flatMap(FootwearSubcategory.init(rawValue:))
        primaryColor = g.primaryColor
        formality = g.formality
        warmth = g.warmth
        seasons = g.seasons
        fit = g.fit
        topLength = g.topLength
        bottomVolume = g.bottomVolume
        structure = g.structure
        fabricWeight = g.fabricWeight
        patternType = g.patternType
        patternScale = g.patternScale
        texture = g.texture
        archetype = g.archetype
    }

    /// Captures a freshly recomputed pipeline result (the re-run loop) off a
    /// `GarmentDraft` that already had `apply(classification:)` run on it. Mirrors
    /// `init(auto:)` so fresh and frozen snapshots are scored by the same axes.
    init(draft d: GarmentDraft) {
        category = d.category
        footwearSubcategory = d.footwearSubcategory
        primaryColor = d.primaryColor
        formality = d.formality
        warmth = d.warmth
        seasons = Season.allCases.filter { d.seasons.contains($0) }
        fit = d.fit
        topLength = d.topLength
        bottomVolume = d.bottomVolume
        structure = d.structure
        fabricWeight = d.fabricWeight
        patternType = d.patternType
        patternScale = d.patternScale
        texture = d.texture
        archetype = d.archetype
    }
}

extension AttributeSnapshot {
    /// One axis, projected to a readable string token (nil = unset). Drives the
    /// at-a-glance divergence marks, the agreement summary and the flat CSV.
    struct Axis: Sendable {
        let key: String
        let title: String
        let token: @Sendable (AttributeSnapshot) -> String?
    }

    /// Every auto-filled axis, in display order. Tokens are the stable `rawValue`
    /// (Int-backed axes stringified) — nonisolated and comparable, matching the
    /// convention in `AttributeEval`. `displayName` is reserved for the MainActor
    /// review UI.
    static let axes: [Axis] = [
        Axis(key: "category",            title: "Category")      { $0.category?.rawValue },
        Axis(key: "footwearSubcategory", title: "Footwear type") { $0.footwearSubcategory?.rawValue },
        Axis(key: "primaryColor",        title: "Primary color") { $0.primaryColor?.rawValue },
        Axis(key: "formality",           title: "Formality")     { $0.formality.map { String($0.rawValue) } },
        Axis(key: "warmth",              title: "Warmth")        { $0.warmth.map { String($0.rawValue) } },
        Axis(key: "seasons",             title: "Seasons")       { s in
            s.seasons.isEmpty ? nil : s.seasons.map(\.rawValue).sorted().joined(separator: "+")
        },
        Axis(key: "fit",          title: "Fit")           { $0.fit?.rawValue },
        Axis(key: "topLength",    title: "Top length")    { $0.topLength?.rawValue },
        Axis(key: "bottomVolume", title: "Bottom volume") { $0.bottomVolume?.rawValue },
        Axis(key: "structure",    title: "Structure")     { $0.structure?.rawValue },
        Axis(key: "fabricWeight", title: "Fabric weight") { $0.fabricWeight?.rawValue },
        Axis(key: "patternType",  title: "Pattern type")  { $0.patternType?.rawValue },
        Axis(key: "patternScale", title: "Pattern scale") { $0.patternScale?.rawValue },
        Axis(key: "texture",      title: "Texture")       { $0.texture?.rawValue },
        Axis(key: "archetype",    title: "Archetype")     { $0.archetype?.rawValue },
    ]
}

/// One garment's review state: the pipeline's `auto` values, the human `truth`,
/// and whether it's been confirmed. Keyed by `Garment.id`.
struct GroundTruthRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String?
    var imageAssetID: String
    var thumbnailAssetID: String
    var auto: AttributeSnapshot
    var truth: AttributeSnapshot
    var reviewed: Bool
    var updatedAt: Date
    /// A freshly recomputed pipeline result (the re-run loop). Never persisted in
    /// the resumable store — only attached on the exported copy — so it stays nil
    /// (and is omitted) in the on-disk review file.
    var fresh: AttributeSnapshot? = nil
    /// Raw classifier features behind the fresh run (surface stats + label). Like
    /// `fresh`, attached only on export — the inputs for offline threshold fitting.
    var features: GarmentFeatures? = nil

    /// Number of axes where the human disagreed with the pipeline.
    var changedAxisCount: Int {
        AttributeSnapshot.axes.reduce(into: 0) { acc, axis in
            if axis.token(auto) != axis.token(truth) { acc += 1 }
        }
    }
}

/// Raw classifier features for one garment from a re-run pass — the inputs the
/// numeric heuristics are computed from, plus the winning label and its confidence.
/// Exported so cutoffs can be fit against ground truth offline. Stats are optional
/// (nil when the foreground mask failed and surface stats couldn't be measured).
struct GarmentFeatures: Codable, Equatable, Sendable {
    var descriptor: String?
    var categoryConfidence: Double
    var luminanceStdDev: Double?
    var edgeDensity: Double?
    var aspect: Double?
    var fillRatio: Double?
}

/// Per-axis agreement between auto and truth over the reviewed records.
struct AxisAgreement: Codable, Equatable {
    let key: String
    let title: String
    let reviewed: Int   // reviewed records considered
    let labeled: Int    // reviewed records whose truth value is set
    let agreed: Int     // labeled records where auto == truth
    var accuracy: Double? { labeled == 0 ? nil : Double(agreed) / Double(labeled) }

    private enum CodingKeys: String, CodingKey { case key, title, reviewed, labeled, agreed, accuracy }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(title, forKey: .title)
        try c.encode(reviewed, forKey: .reviewed)
        try c.encode(labeled, forKey: .labeled)
        try c.encode(agreed, forKey: .agreed)
        try c.encodeIfPresent(accuracy, forKey: .accuracy)
    }
    init(key: String, title: String, reviewed: Int, labeled: Int, agreed: Int) {
        self.key = key; self.title = title; self.reviewed = reviewed
        self.labeled = labeled; self.agreed = agreed
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        key = try c.decode(String.self, forKey: .key)
        title = try c.decode(String.self, forKey: .title)
        reviewed = try c.decode(Int.self, forKey: .reviewed)
        labeled = try c.decode(Int.self, forKey: .labeled)
        agreed = try c.decode(Int.self, forKey: .agreed)
    }
}

/// The exported document: a summary block plus every garment's auto/truth pair.
/// When a re-run scoring pass has happened, `freshAxes`/`lastRunAt` and each
/// record's `fresh` snapshot carry the current pipeline's output for offline diff.
struct GroundTruthExport: Codable {
    let exportedAt: Date
    let total: Int
    let reviewedCount: Int
    let axes: [AxisAgreement]
    var freshAxes: [AxisAgreement]? = nil
    var lastRunAt: Date? = nil
    let records: [GroundTruthRecord]
}
#endif
