//
//  DebugHarnessView.swift
//  drape
//
//  DEBUG-ONLY. The visual cockpit for the test harness: import a synthetic
//  wardrobe, scan inferred attributes, read autofill accuracy, and run the engine
//  playground with per-scorer breakdowns. Reached from Profile → Developer. Uses
//  its own in-memory store + container so it never touches the user's wardrobe.
//

#if DEBUG
import SwiftUI
import SwiftData
import UniformTypeIdentifiers

@MainActor
@Observable
final class DebugHarnessModel {
    var records: [DebugImportRecord] = []
    var garmentsByID: [UUID: Garment] = [:]
    var isImporting = false
    var progressText: String?
    var statusText: String?
    /// Folder to import real images from (e.g. a CC0 dataset). Defaults to a
    /// `clothing-dataset-small` directory in the app's Documents.
    var datasetPath: String

    /// Absolute Documents path, shown so the dataset can be copied into place.
    var documentsHint: String { URL.documentsDirectory.path }

    var wardrobe: DebugWardrobe = .mixed
    var occasion: Occasion = .everyday
    var temperature: Double = 20
    var playground: [RuleBasedRecommendationEngine.DebugOutfitScore] = []

    /// Debug image store + container, isolated from the user's data.
    let store = InMemoryImageStore()
    let container: ModelContainer
    let appContainer: AppContainer
    private let engine = RuleBasedRecommendationEngine()

    init(live: AppContainer) {
        datasetPath = URL.documentsDirectory.appendingPathComponent("clothing-dataset-small").path
        container = ModelContainer.previewContainer(seeded: false)
        // Same real services as the app, but writing images to the debug store so
        // NormalizedImageView resolves them in this subtree.
        appContainer = AppContainer(
            imageProcessor: live.imageProcessor,
            imageStore: store,
            classifier: live.classifier,
            styleArchetype: live.styleArchetype,
            weather: live.weather,
            location: live.location,
            recommendationEngine: live.recommendationEngine,
            entitlements: live.entitlements)
    }

    func importSmoke() async {
        await runImport(SyntheticDebugImageProvider.smokeItems(count: 24))
    }

    func importFolder() async {
        let items = DebugDatasetFolderSource.load(
            directory: URL(fileURLWithPath: datasetPath), datasetID: "clothing-dataset-small")
        await runImport(items)
    }

    /// Imports a dataset folder the user picked from Finder/Files. The picked URL
    /// is security-scoped under the sandbox, so access must be opened around the
    /// (synchronous) read in `DebugDatasetFolderSource.load`.
    func importPickedFolder(_ url: URL) async {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        datasetPath = url.path
        let items = DebugDatasetFolderSource.load(directory: url, datasetID: url.lastPathComponent)
        await runImport(items)
    }

    private func runImport(_ items: [DebugImageItem]) async {
        isImporting = true
        defer { isImporting = false; progressText = nil }
        playground = []
        guard !items.isEmpty else {
            statusText = "No images found at that path."
            return
        }
        // Start clean so successive imports don't accumulate garments.
        if let existing = try? container.mainContext.fetch(FetchDescriptor<Garment>()) {
            existing.forEach { container.mainContext.delete($0) }
        }
        let importer = DebugWardrobeImporter(
            imageProcessor: appContainer.imageProcessor,
            classifier: appContainer.classifier,
            styleArchetype: appContainer.styleArchetype,
            imageStore: store)
        records = await importer.importItems(items, into: container.mainContext) { done, total in
            self.progressText = "Importing \(done)/\(total)…"
        }
        let garments = (try? container.mainContext.fetch(FetchDescriptor<Garment>())) ?? []
        garmentsByID = Dictionary(garments.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        statusText = "Imported \(records.count) garments."
    }

    var report: AttributeEvalReport { AttributeEval.evaluate(records, on: nil) }
    var selected: [DebugImportRecord] { wardrobe.select(from: records) }

    func runPlayground() async {
        let ctx = RecommendationContext(
            wardrobe: selected.map(\.inferred),
            occasion: occasion,
            weather: WeatherSnapshot(temperatureCelsius: temperature),
            desiredCount: 3)
        playground = await engine.scoreBreakdown(ctx)
    }
}

struct DebugHarnessView: View {
    @Environment(AppContainer.self) private var live
    @State private var model: DebugHarnessModel?
    @State private var pickingFolder = false

    var body: some View {
        ScrollView {
            if let model {
                content(model)
                    .environment(model.appContainer)   // resolve debug-store images
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Test harness")
        .navigationBarTitleDisplayMode(.inline)
        .task { if model == nil { model = DebugHarnessModel(live: live) } }
    }

    @ViewBuilder
    private func content(_ model: DebugHarnessModel) -> some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 20) {
            importSection(model)
            folderSection(model, $model)
            if !model.records.isEmpty {
                metricsSection(model)
                wardrobeSection($model.wardrobe, count: model.selected.count)
                playgroundSection(model, $model)
                reviewSection(model)
            }
        }
        .padding(Theme.contentPadding)
    }

    // MARK: - Import

    private func importSection(_ model: DebugHarnessModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Synthetic wardrobe")
            Text("Category model: \(VisionGarmentClassifier.categoryModelAvailable ? "loaded ✓" : "missing ✗") — runs on device only (its scenePrint feature extractor isn't in the Simulator runtime)")
                .font(Theme.mono(11)).foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text("Flat symbol renders — exercises the pipeline, not autofill quality. Drop CC0 images locally for real metrics.")
                .font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
            Button {
                Task { await model.importSmoke() }
            } label: {
                Text(model.isImporting ? (model.progressText ?? "Importing…") : "Import 24 synthetic garments")
                    .font(Theme.body(15, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(model.isImporting)
        }
    }

    // MARK: - Folder import (real CC0 dataset)

    private func folderSection(_ model: DebugHarnessModel, _ binding: Bindable<DebugHarnessModel>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Local dataset (CC0)")
            Text("Pick a dataset folder from Finder/Files, or drop one into Drape's Documents and paste its path. ~20 images/class are sampled; train→dev, validation/test→holdout.")
                .font(Theme.body(12)).foregroundStyle(Theme.inkSoft)
            Button {
                pickingFolder = true
            } label: {
                Text("Choose folder in Finder/Files…")
                    .font(Theme.body(15, weight: .semibold))
                    .foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(model.isImporting)
            .fileImporter(isPresented: $pickingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    Task { await model.importPickedFolder(url) }
                }
            }
            TextField("Dataset path", text: binding.datasetPath, axis: .vertical)
                .font(Theme.mono(11))
                .lineLimit(1...3)
                .padding(10)
                .drapeCard(radius: 10)
            Button {
                Task { await model.importFolder() }
            } label: {
                Text("Import from path")
                    .font(Theme.body(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.ink, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(model.isImporting)
            if let status = model.statusText {
                Text(status).font(Theme.mono(11)).foregroundStyle(Theme.inkSoft)
            }
            Text("Documents: \(model.documentsHint)")
                .font(Theme.mono(9)).foregroundStyle(Theme.inkFaint)
                .textSelection(.enabled)
        }
    }

    // MARK: - Metrics

    private func metricsSection(_ model: DebugHarnessModel) -> some View {
        let report = model.report
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Autofill — \(report.total) items · coverage · accuracy")
                    .padding(.horizontal, 16).padding(.vertical, 13)
                ForEach(report.metrics, id: \.name) { m in
                    Theme.line.frame(height: 0.5)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(m.name).font(Theme.body(14))
                            Spacer()
                            Text("cov \(pct(m.coverage)) · acc \(m.accuracy.map(pct) ?? "—")")
                                .font(Theme.mono(12)).foregroundStyle(Theme.inkSoft)
                        }
                        if !m.distribution.isEmpty {
                            // Value distribution — spots a degenerate heuristic.
                            Text(m.distribution.prefix(4).map { "\($0.value)×\($0.count)" }.joined(separator: "  "))
                                .font(Theme.mono(10)).foregroundStyle(Theme.inkFaint)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .drapeCard(radius: 14)

            if !report.confusionTally.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    MonoLabel("Category confusions (expected → got)")
                        .padding(.horizontal, 16).padding(.vertical, 13)
                    ForEach(Array(report.confusionTally.prefix(8).enumerated()), id: \.offset) { _, c in
                        Theme.line.frame(height: 0.5)
                        HStack {
                            Text("\(c.expected) → \(c.got)").font(Theme.mono(12))
                            Spacer()
                            Text("×\(c.count)").font(Theme.mono(12)).foregroundStyle(Theme.inkSoft)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 9)
                    }
                }
                .drapeCard(radius: 14)
            }
        }
    }

    // MARK: - Wardrobe picker

    private func wardrobeSection(_ selection: Binding<DebugWardrobe>, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Wardrobe — \(count) pieces")
            Picker("Wardrobe", selection: selection) {
                ForEach(DebugWardrobe.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Engine playground

    private func playgroundSection(_ model: DebugHarnessModel, _ binding: Bindable<DebugHarnessModel>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel("Engine playground")
            Picker("Occasion", selection: binding.occasion) {
                ForEach(Occasion.allCases) { Text($0.displayName).tag($0) }
            }
            .pickerStyle(.menu)
            HStack {
                Text("Temp \(Int(model.temperature))°C").font(Theme.body(13))
                Slider(value: binding.temperature, in: -5...35, step: 1)
            }
            Button("Run engine") { Task { await model.runPlayground() } }
                .font(Theme.body(15, weight: .semibold))
                .foregroundStyle(Theme.ink)

            ForEach(Array(model.playground.enumerated()), id: \.offset) { _, outfit in
                outfitBreakdown(outfit, model: model)
            }
        }
    }

    private func outfitBreakdown(_ outfit: RuleBasedRecommendationEngine.DebugOutfitScore, model: DebugHarnessModel) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(outfit.garmentIDs.compactMap { model.garmentsByID[$0]?.displayName }.joined(separator: " · "))
                    .font(Theme.body(13)).lineLimit(2)
                Spacer()
                Text(pct(outfit.normalized)).font(Theme.mono(13))
            }
            ForEach(outfit.contributions.sorted { $0.weighted > $1.weighted }.prefix(4), id: \.axis) { c in
                HStack(spacing: 8) {
                    Text(c.axis).font(Theme.mono(10)).frame(width: 70, alignment: .leading)
                    GeometryReader { geo in
                        Theme.ink.opacity(0.8)
                            .frame(width: geo.size.width * c.raw)
                            .clipShape(Capsule())
                    }
                    .frame(height: 6)
                    Text(String(format: "%.2f", c.raw)).font(Theme.mono(10)).foregroundStyle(Theme.inkSoft)
                }
            }
        }
        .padding(12)
        .drapeCard(radius: 12)
    }

    // MARK: - Attribute review

    private func reviewSection(_ model: DebugHarnessModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Inferred attributes")
            ForEach(model.records, id: \.sourceID) { record in
                if let garment = model.garmentsByID[record.garmentID] {
                    reviewRow(garment)
                }
            }
        }
    }

    private func reviewRow(_ garment: Garment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            NormalizedImageView(assetID: garment.thumbnailAssetID)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 6) {
                Text(garment.displayName).font(Theme.body(14))
                FlowLayout(spacing: 5) {
                    ForEach(attributeChips(garment), id: \.self) { TagChip($0) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .drapeCard(radius: 12)
    }

    private func attributeChips(_ g: Garment) -> [String] {
        [g.category.displayName, g.primaryColor.displayName,
         g.fit?.displayName, g.structure?.displayName, g.texture?.displayName,
         g.patternType?.displayName, g.archetype?.displayName].compactMap { $0 }
    }

    private func pct(_ x: Double) -> String { "\(Int((x * 100).rounded()))%" }
}
#endif
