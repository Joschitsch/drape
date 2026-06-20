//
//  DebugGarmentReviewView.swift
//  drape
//
//  DEBUG-ONLY. Reviews one real garment: its full image stays pinned at the top
//  (the hard constraint — you must clearly see the piece while judging it) while a
//  scrolling list of every auto-filled axis lets you correct the pipeline's guess.
//  Each field starts pre-filled with the guess; you change only what's wrong, then
//  mark the item reviewed. Edits persist immediately via `GroundTruthStore`.
//

#if DEBUG
import SwiftUI

/// Shared shape for the axis pickers: every classification enum already has these,
/// so an empty conformance is enough to drive a generic picker row.
protocol AxisValue: CaseIterable, Hashable, Identifiable {
    var displayName: String { get }
}
extension GarmentCategory: AxisValue {}
extension FootwearSubcategory: AxisValue {}
extension ColorTag: AxisValue {}
extension Formality: AxisValue {}
extension WarmthLevel: AxisValue {}
extension Fit: AxisValue {}
extension TopLength: AxisValue {}
extension BottomVolume: AxisValue {}
extension Structure: AxisValue {}
extension FabricWeight: AxisValue {}
extension PatternType: AxisValue {}
extension PatternScale: AxisValue {}
extension Texture: AxisValue {}
extension Archetype: AxisValue {}

struct DebugGarmentReviewView: View {
    let garment: Garment
    let store: GroundTruthStore

    @Environment(AppContainer.self) private var container

    private var id: UUID { garment.id }
    private var record: GroundTruthRecord? { store.record(for: id) }

    var body: some View {
        VStack(spacing: 0) {
            imageHeader
            Theme.line.frame(height: 0.5)
            attributeList
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle(garment.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Pinned image

    private var imageHeader: some View {
        NormalizedImageView(assetID: garment.imageAssetID, useThumbnail: false)
            .frame(maxWidth: .infinity)
            .frame(height: 300)
            .background(Theme.surface)
    }

    // MARK: - Attributes

    private var attributeList: some View {
        ScrollView {
            VStack(spacing: 0) {
                controlsRow
                Theme.line.frame(height: 0.5)

                axisRow("Category", auto: record?.auto.category, binding: optBinding(\.category))
                axisRow("Footwear type", auto: record?.auto.footwearSubcategory, binding: optBinding(\.footwearSubcategory))
                colorRow
                axisRow("Formality", auto: record?.auto.formality, binding: optBinding(\.formality))
                axisRow("Warmth", auto: record?.auto.warmth, binding: optBinding(\.warmth))
                seasonsRow
                axisRow("Fit", auto: record?.auto.fit, binding: optBinding(\.fit))
                axisRow("Top length", auto: record?.auto.topLength, binding: optBinding(\.topLength))
                axisRow("Bottom volume", auto: record?.auto.bottomVolume, binding: optBinding(\.bottomVolume))
                axisRow("Structure", auto: record?.auto.structure, binding: optBinding(\.structure))
                axisRow("Fabric weight", auto: record?.auto.fabricWeight, binding: optBinding(\.fabricWeight))
                axisRow("Pattern type", auto: record?.auto.patternType, binding: optBinding(\.patternType))
                axisRow("Pattern scale", auto: record?.auto.patternScale, binding: optBinding(\.patternScale))
                axisRow("Texture", auto: record?.auto.texture, binding: optBinding(\.texture))
                axisRow("Archetype", auto: record?.auto.archetype, binding: optBinding(\.archetype))
            }
            .padding(.bottom, 24)
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 12) {
            Button {
                store.update(id) { $0.reviewed.toggle() }
            } label: {
                Label(
                    (record?.reviewed ?? false) ? "Reviewed" : "Mark reviewed",
                    systemImage: (record?.reviewed ?? false) ? "checkmark.circle.fill" : "circle"
                )
                .font(Theme.body(14, weight: .medium))
                .foregroundStyle((record?.reviewed ?? false) ? .green : Theme.ink)
            }
            .buttonStyle(.plain)

            Spacer()

            if (record?.changedAxisCount ?? 0) > 0 {
                Button("Reset to auto") { store.resetToAuto(id) }
                    .font(Theme.body(13))
                    .foregroundStyle(.orange)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.contentPadding)
        .padding(.vertical, 14)
    }

    // MARK: - Row builders

    private func optBinding<T>(_ kp: WritableKeyPath<AttributeSnapshot, T?>) -> Binding<T?> {
        Binding(
            get: { store.record(for: id)?.truth[keyPath: kp] },
            set: { v in store.update(id) { $0.truth[keyPath: kp] = v } }
        )
    }

    @ViewBuilder
    private func axisRow<T: AxisValue>(_ title: String, auto: T?, binding: Binding<T?>) -> some View {
        let diverged = auto != binding.wrappedValue
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(Theme.body(14.5))
                        .foregroundStyle(Theme.ink)
                    Text("auto: \(auto?.displayName ?? "—")")
                        .font(Theme.body(11.5))
                        .foregroundStyle(Theme.inkSoft)
                }
                Spacer(minLength: 8)
                divergenceDot(diverged)
                Picker(title, selection: binding) {
                    Text("—").tag(Optional<T>.none)
                    ForEach(Array(T.allCases)) { c in
                        Text(c.displayName).tag(Optional(c))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(diverged ? .orange : Theme.ink)
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.vertical, 11)
            Theme.line.frame(height: 0.5)
        }
    }

    /// Primary color gets swatches alongside each option for fast eyeballing.
    private var colorRow: some View {
        let binding = optBinding(\AttributeSnapshot.primaryColor)
        let auto = record?.auto.primaryColor
        let diverged = auto != binding.wrappedValue
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Primary color")
                        .font(Theme.body(14.5))
                        .foregroundStyle(Theme.ink)
                    HStack(spacing: 5) {
                        Text("auto:")
                            .font(Theme.body(11.5))
                            .foregroundStyle(Theme.inkSoft)
                        if let auto {
                            Circle().fill(auto.color).frame(width: 11, height: 11)
                                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
                        }
                        Text(auto?.displayName ?? "—")
                            .font(Theme.body(11.5))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer(minLength: 8)
                divergenceDot(diverged)
                Picker("Primary color", selection: binding) {
                    Text("—").tag(Optional<ColorTag>.none)
                    ForEach(ColorTag.allCases) { c in
                        Label(c.displayName, systemImage: "circle.fill")
                            .tint(c.color)
                            .tag(Optional(c))
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .tint(diverged ? .orange : Theme.ink)
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.vertical, 11)
            Theme.line.frame(height: 0.5)
        }
    }

    /// Seasons are multi-valued — chip toggles instead of a single picker.
    private var seasonsRow: some View {
        let autoTokens = Set(record?.auto.seasons ?? [])
        let truth = Set(record?.truth.seasons ?? [])
        let diverged = autoTokens != truth
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Seasons")
                        .font(Theme.body(14.5))
                        .foregroundStyle(Theme.ink)
                    divergenceDot(diverged)
                    Spacer()
                }
                Text("auto: \(autoTokens.isEmpty ? "—" : Season.allCases.filter(autoTokens.contains).map(\.displayName).joined(separator: ", "))")
                    .font(Theme.body(11.5))
                    .foregroundStyle(Theme.inkSoft)
                HStack(spacing: 8) {
                    ForEach(Season.allCases) { season in
                        DrapeChip(label: season.displayName, active: truth.contains(season), small: true) {
                            store.update(id) { rec in
                                if let idx = rec.truth.seasons.firstIndex(of: season) {
                                    rec.truth.seasons.remove(at: idx)
                                } else {
                                    rec.truth.seasons.append(season)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.vertical, 11)
            Theme.line.frame(height: 0.5)
        }
    }

    @ViewBuilder
    private func divergenceDot(_ diverged: Bool) -> some View {
        if diverged {
            Circle().fill(.orange).frame(width: 7, height: 7)
                .accessibilityLabel("Differs from auto")
        }
    }
}
#endif
