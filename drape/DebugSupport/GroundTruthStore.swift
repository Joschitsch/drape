//
//  GroundTruthStore.swift
//  drape
//
//  DEBUG-ONLY. Persists the ground-truth review pass so the 57-item review is
//  resumable across launches, and builds the JSON + CSV export. Backed by a single
//  JSON file in Application Support (same home as `FileImageStore`'s images),
//  entirely separate from the SwiftData store — `Garment` is never mutated.
//

#if DEBUG
import Foundation
import Observation

@MainActor
@Observable
final class GroundTruthStore {
    /// Keyed by `Garment.id`.
    private(set) var records: [UUID: GroundTruthRecord] = [:]

    /// Freshly recomputed pipeline results from the re-run loop, keyed by
    /// `Garment.id`. In-memory only (reflects the *current* build); never persisted.
    private(set) var fresh: [UUID: AttributeSnapshot] = [:]
    /// Raw classifier features captured during the same re-run, keyed by `Garment.id`.
    private(set) var features: [UUID: GarmentFeatures] = [:]
    /// When the last re-run pass finished.
    private(set) var lastRunAt: Date?

    private let fileURL: URL

    init() {
        let dir = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true))?
            .appendingPathComponent("DebugGroundTruth", isDirectory: true)
            ?? FileManager.default.temporaryDirectory.appendingPathComponent("DebugGroundTruth", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("ground-truth.json")
        load()
    }

    // MARK: - Lookup

    func record(for id: UUID) -> GroundTruthRecord? { records[id] }

    var reviewedCount: Int { records.values.filter(\.reviewed).count }

    // MARK: - Sync with the real wardrobe

    /// Seeds a record (truth pre-filled with the pipeline's guess) for any garment
    /// that doesn't have one yet. Never overwrites existing user edits. Prunes
    /// records whose garment was deleted, so stale rows don't linger in the export.
    func sync(with garments: [Garment]) {
        var changed = false
        let liveIDs = Set(garments.map(\.id))

        for g in garments where records[g.id] == nil {
            let auto = AttributeSnapshot(auto: g)
            records[g.id] = GroundTruthRecord(
                id: g.id,
                name: g.name,
                imageAssetID: g.imageAssetID,
                thumbnailAssetID: g.thumbnailAssetID,
                auto: auto,
                truth: auto,          // pre-fill workflow: start at the guess
                reviewed: false,
                updatedAt: .now)
            changed = true
        }
        for staleID in records.keys where !liveIDs.contains(staleID) {
            records.removeValue(forKey: staleID); changed = true
        }
        if changed { save() }
    }

    // MARK: - Edits (auto-saving)

    /// Mutates a record in place, bumps `updatedAt`, and persists immediately so
    /// the pass survives a force-quit.
    func update(_ id: UUID, _ mutate: (inout GroundTruthRecord) -> Void) {
        guard var rec = records[id] else { return }
        mutate(&rec)
        rec.updatedAt = .now
        records[id] = rec
        save()
    }

    /// Discards the human edits for one garment, snapping truth back to the guess.
    func resetToAuto(_ id: UUID) {
        update(id) { $0.truth = $0.auto; $0.reviewed = false }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let list = try? Self.decoder.decode([GroundTruthRecord].self, from: data)
        else { return }
        records = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    private func save() {
        let list = records.values.sorted { $0.updatedAt < $1.updatedAt }
        guard let data = try? Self.encoder.encode(Array(list)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Re-run scoring loop

    /// Records a freshly recomputed pipeline snapshot for one garment.
    func setFresh(_ snapshot: AttributeSnapshot, for id: UUID) { fresh[id] = snapshot }

    /// Records the raw classifier features behind one garment's fresh run.
    func setFeatures(_ f: GarmentFeatures, for id: UUID) { features[id] = f }

    /// Stamps a completed re-run pass.
    func markRunComplete() { lastRunAt = .now }

    /// Drops all re-run results (e.g. before starting a fresh pass).
    func clearFresh() { fresh = [:]; features = [:]; lastRunAt = nil }

    var hasFreshRun: Bool { !fresh.isEmpty }

    /// Per-axis agreement of the *freshly recomputed* values vs. ground truth, over
    /// reviewed records that have a fresh snapshot. Same shape as `axisAgreements()`
    /// so the UI can show a frozen-auto → fresh delta.
    func freshAgreements() -> [AxisAgreement] {
        let reviewed = records.values.filter { $0.reviewed && fresh[$0.id] != nil }
        return AttributeSnapshot.axes.map { axis in
            var labeled = 0, agreed = 0
            for r in reviewed {
                guard let truth = axis.token(r.truth), let f = fresh[r.id] else { continue }
                labeled += 1
                if axis.token(f) == truth { agreed += 1 }
            }
            return AxisAgreement(key: axis.key, title: axis.title,
                                 reviewed: reviewed.count, labeled: labeled, agreed: agreed)
        }
    }

    /// Category misses (expected → got) of the fresh run, most common first.
    func categoryConfusions() -> [ConfusionRow] {
        let axis = AttributeSnapshot.axes.first { $0.key == "category" }!
        var tally: [String: Int] = [:]
        for r in records.values where r.reviewed {
            guard let truth = axis.token(r.truth), let f = fresh[r.id],
                  let got = axis.token(f), got != truth else { continue }
            tally["\(truth)→\(got)", default: 0] += 1
        }
        return tally
            .map { key, count -> ConfusionRow in
                let parts = key.split(separator: "→", maxSplits: 1)
                return ConfusionRow(expected: String(parts[0]),
                                    got: String(parts.count > 1 ? parts[1] : ""), count: count)
            }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.expected < $1.expected }
    }

    struct ConfusionRow: Identifiable {
        let id = UUID()
        let expected: String
        let got: String
        let count: Int
    }

    // MARK: - Export

    /// Per-axis agreement over the reviewed records.
    func axisAgreements() -> [AxisAgreement] {
        let reviewed = records.values.filter(\.reviewed)
        return AttributeSnapshot.axes.map { axis in
            var labeled = 0, agreed = 0
            for r in reviewed {
                guard let truth = axis.token(r.truth) else { continue }
                labeled += 1
                if axis.token(r.auto) == truth { agreed += 1 }
            }
            return AxisAgreement(key: axis.key, title: axis.title,
                                 reviewed: reviewed.count, labeled: labeled, agreed: agreed)
        }
    }

    private func buildExport() -> GroundTruthExport {
        let recs = records.values
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
            .map { r -> GroundTruthRecord in
                var copy = r
                copy.fresh = fresh[r.id]          // attach the current run, if any
                copy.features = features[r.id]
                return copy
            }
        return GroundTruthExport(
            exportedAt: .now,
            total: records.count,
            reviewedCount: reviewedCount,
            axes: axisAgreements(),
            freshAxes: hasFreshRun ? freshAgreements() : nil,
            lastRunAt: lastRunAt,
            records: recs)
    }

    /// Writes `ground-truth-export.json` and `.csv` to a temp dir and returns both
    /// URLs for a share sheet.
    func exportFiles() throws -> [URL] {
        let export = buildExport()
        let dir = FileManager.default.temporaryDirectory
        let stamp = Self.fileStamp.string(from: export.exportedAt)

        let jsonURL = dir.appendingPathComponent("ground-truth-\(stamp).json")
        try Self.encoder.encode(export).write(to: jsonURL, options: .atomic)

        let csvURL = dir.appendingPathComponent("ground-truth-\(stamp).csv")
        try Data(csv(for: export).utf8).write(to: csvURL, options: .atomic)

        return [jsonURL, csvURL]
    }

    /// One row per garment: identity, then `<axis>_auto`, `<axis>_truth`,
    /// `<axis>_match` triples for every axis.
    private func csv(for export: GroundTruthExport) -> String {
        let hasFresh = export.records.contains { $0.fresh != nil }
        let hasFeatures = export.records.contains { $0.features != nil }
        var header = ["id", "name", "reviewed"]
        for axis in AttributeSnapshot.axes {
            header += ["\(axis.key)_auto", "\(axis.key)_truth", "\(axis.key)_match"]
            if hasFresh { header += ["\(axis.key)_fresh", "\(axis.key)_freshmatch"] }
        }
        if hasFeatures {
            header += ["feat_descriptor", "feat_categoryConfidence",
                       "feat_luminanceStdDev", "feat_edgeDensity", "feat_aspect", "feat_fillRatio"]
        }
        var rows = [header.map(Self.escapeCSV).joined(separator: ",")]

        for r in export.records {
            var cells = [r.id.uuidString, r.name ?? "", r.reviewed ? "yes" : "no"]
            for axis in AttributeSnapshot.axes {
                let a = axis.token(r.auto) ?? ""
                let t = axis.token(r.truth) ?? ""
                cells += [a, t, a == t ? "1" : "0"]
                if hasFresh {
                    let f = r.fresh.flatMap(axis.token) ?? ""
                    cells += [f, f == t ? "1" : "0"]
                }
            }
            if hasFeatures {
                let f = r.features
                func num(_ v: Double?) -> String { v.map { String(format: "%.4f", $0) } ?? "" }
                cells += [f?.descriptor ?? "", num(f?.categoryConfidence),
                          num(f?.luminanceStdDev), num(f?.edgeDensity), num(f?.aspect), num(f?.fillRatio)]
            }
            rows.append(cells.map(Self.escapeCSV).joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escapeCSV(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - Coders

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f
    }()
}
#endif
