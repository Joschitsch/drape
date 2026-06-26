//
//  DebugGroundTruthView.swift
//  drape
//
//  DEBUG-ONLY. The ground-truth review cockpit, reached from Profile → Developer.
//  Reads the *real* wardrobe (the user's actual garments) and lets each be reviewed
//  against its auto-filled attributes, with progress, a live agreement summary, and
//  a JSON + CSV export. Nothing here mutates `Garment` — judgments live in a
//  separate `GroundTruthStore`.
//

#if DEBUG
import SwiftUI
import SwiftData
import UIKit

struct DebugGroundTruthView: View {
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @Environment(AppContainer.self) private var container

    @State private var store = GroundTruthStore()
    @State private var shareItems: [URL] = []
    @State private var showingShare = false
    @State private var exportError: String?

    @State private var isRunning = false
    @State private var runDone = 0
    @State private var runTotal = 0

    var body: some View {
        List {
            summarySection
            rerunSection
            garmentSection
        }
        .listStyle(.plain)
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Ground Truth")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { exportTapped() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(garments.isEmpty)
                    .accessibilityLabel("Export ground truth")
            }
        }
        .task { store.sync(with: garments) }
        .sheet(isPresented: $showingShare) { ShareSheet(items: shareItems) }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil }, set: { if !$0 { exportError = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: { Text(exportError ?? "") }
    }

    // MARK: - Summary

    private var reviewed: Int { store.reviewedCount }

    @ViewBuilder
    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MonoLabel("Progress")
                    Spacer()
                    Text("\(reviewed) / \(garments.count) reviewed")
                        .font(Theme.body(13, weight: .medium))
                        .foregroundStyle(Theme.ink)
                }
                ProgressView(value: Double(reviewed),
                             total: Double(max(garments.count, 1)))
                    .tint(Theme.ink)

                if reviewed > 0 {
                    Theme.line.frame(height: 0.5)
                    MonoLabel("Auto vs. ground truth (reviewed)")
                    ForEach(store.axisAgreements(), id: \.key) { a in
                        HStack {
                            Text(a.title)
                                .font(Theme.body(12.5))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(accuracyLabel(a))
                                .font(Theme.body(12.5, weight: .medium))
                                .foregroundStyle(accuracyColor(a))
                                .monospacedDigit()
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func accuracyLabel(_ a: AxisAgreement) -> String {
        guard let acc = a.accuracy else { return "—" }
        return "\(Int((acc * 100).rounded()))%  (\(a.agreed)/\(a.labeled))"
    }

    private func accuracyColor(_ a: AxisAgreement) -> Color {
        guard let acc = a.accuracy else { return Theme.inkFaint }
        if acc >= 0.8 { return .green }
        if acc >= 0.5 { return .orange }
        return .red
    }

    // MARK: - Re-run & score

    @ViewBuilder
    private var rerunSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    MonoLabel("Re-run pipeline")
                    Spacer()
                    Button {
                        Task { await runScoring() }
                    } label: {
                        Text(isRunning ? "Running…" : "Re-run & score")
                            .font(Theme.body(13, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRunning || garments.isEmpty)
                }

                if isRunning {
                    ProgressView(value: Double(runDone), total: Double(max(runTotal, 1)))
                        .tint(Theme.ink)
                    Text("\(runDone) / \(runTotal) reclassified")
                        .font(Theme.body(11.5))
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Text("Reclassifies each garment's stored image with the current build and scores it against your ground truth — no re-upload needed.")
                        .font(Theme.body(11.5))
                        .foregroundStyle(Theme.inkSoft)
                }

                if store.hasFreshRun, reviewed > 0 {
                    Theme.line.frame(height: 0.5)
                    MonoLabel("Frozen auto → fresh (reviewed)")
                    ForEach(deltaRows(), id: \.fresh.key) { row in
                        HStack {
                            Text(row.fresh.title)
                                .font(Theme.body(12.5))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(deltaLabel(auto: row.auto, fresh: row.fresh))
                                .font(Theme.body(12.5, weight: .medium))
                                .foregroundStyle(accuracyColor(row.fresh))
                                .monospacedDigit()
                        }
                    }

                    let confusions = store.categoryConfusions()
                    if !confusions.isEmpty {
                        Theme.line.frame(height: 0.5)
                        MonoLabel("Category misses (truth → got)")
                        ForEach(confusions) { c in
                            HStack {
                                Text("\(c.expected) → \(c.got)")
                                    .font(Theme.body(12.5))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(c.count)")
                                    .font(Theme.body(12.5, weight: .medium))
                                    .foregroundStyle(.red)
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// Pairs each axis's frozen-auto agreement with its fresh agreement.
    private func deltaRows() -> [(auto: AxisAgreement, fresh: AxisAgreement)] {
        let autoByKey = Dictionary(uniqueKeysWithValues: store.axisAgreements().map { ($0.key, $0) })
        return store.freshAgreements().compactMap { f in
            autoByKey[f.key].map { (auto: $0, fresh: f) }
        }
    }

    private func deltaLabel(auto: AxisAgreement, fresh: AxisAgreement) -> String {
        guard let fa = fresh.accuracy else { return "—" }
        let freshPct = Int((fa * 100).rounded())
        guard let aa = auto.accuracy else { return "\(freshPct)%" }
        let autoPct = Int((aa * 100).rounded())
        let delta = freshPct - autoPct
        let sign = delta > 0 ? "+" : ""
        return "\(autoPct)% → \(freshPct)%  (\(sign)\(delta))"
    }

    private func runScoring() async {
        isRunning = true
        store.clearFresh()
        let items = garments
        runTotal = items.count
        runDone = 0
        for g in items {
            defer { runDone += 1 }
            guard !g.imageAssetID.isEmpty else { continue }
            guard let data = try? await container.imageStore.loadImageData(id: g.imageAssetID) else { continue }
            // Classify the stored (already-normalized) bytes directly — the same
            // input the classifier saw at upload — so this faithfully reproduces
            // and then tracks improvements to upload-time inference. When the
            // classifier supports it, also capture the raw surface features that the
            // numeric heuristics are computed from, for offline threshold fitting.
            let suggestion: ClassificationSuggestion
            var diagnostics: ClassifierDiagnostics?
            if let diag = container.classifier as? DiagnosticGarmentClassifier {
                (suggestion, diagnostics) = await diag.classifyWithDiagnostics(imageData: data)
            } else {
                suggestion = await container.classifier.classify(imageData: data)
            }
            var draft = GarmentDraft()
            draft.apply(classification: suggestion)
            if let a = await container.styleArchetype.inferArchetype(
                    descriptor: suggestion.descriptor, category: draft.category, styles: []) {
                draft.styles.insert(a.rawValue)
            }
            store.setFresh(AttributeSnapshot(draft: draft), for: g.id)
            store.setFeatures(GarmentFeatures(
                descriptor: suggestion.descriptor,
                categoryConfidence: suggestion.categoryConfidence,
                luminanceStdDev: diagnostics?.luminanceStdDev,
                edgeDensity: diagnostics?.edgeDensity,
                aspect: diagnostics?.aspect,
                fillRatio: diagnostics?.fillRatio), for: g.id)
        }
        store.markRunComplete()
        isRunning = false
    }

    // MARK: - Garment list

    @ViewBuilder
    private var garmentSection: some View {
        Section {
            if garments.isEmpty {
                Text("No garments in the wardrobe yet.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.inkSoft)
            } else {
                ForEach(garments) { garment in
                    NavigationLink {
                        DebugGarmentReviewView(garment: garment, store: store)
                    } label: {
                        row(for: garment)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func row(for garment: Garment) -> some View {
        let rec = store.record(for: garment.id)
        HStack(spacing: 12) {
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text(garment.displayName)
                    .font(Theme.body(14.5))
                    .foregroundStyle(Theme.ink)
                Text(garment.category.displayName)
                    .font(Theme.body(11.5))
                    .foregroundStyle(Theme.inkSoft)
            }

            Spacer(minLength: 0)

            if let rec, rec.changedAxisCount > 0 {
                Text("\(rec.changedAxisCount) changed")
                    .font(Theme.body(10.5, weight: .medium))
                    .foregroundStyle(.orange)
            }
            Image(systemName: (rec?.reviewed ?? false) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle((rec?.reviewed ?? false) ? .green : Theme.inkFaint)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Export

    private func exportTapped() {
        do {
            shareItems = try store.exportFiles()
            showingShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

#endif
