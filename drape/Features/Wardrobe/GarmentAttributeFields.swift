//
//  GarmentAttributeFields.swift
//  drape
//
//  Shared Form content for editing a GarmentDraft (add + edit flows).
//

import SwiftUI

/// The attribute editor used by both the add and edit screens. Renders as a set
/// of `Section`s; the host view supplies the enclosing `Form`.
struct GarmentAttributeFields: View {
    @Binding var draft: GarmentDraft
    @State private var customColor: Color = .clear

    var body: some View {
        Section("Basics") {
            TextField("Name", text: $draft.name)
            Picker("Category", selection: $draft.category) {
                ForEach(GarmentCategory.allCases) { category in
                    Label(category.displayName, systemImage: category.systemImage).tag(category)
                }
            }
            colorRow
        }

        Section("Suitability") {
            Picker("Formality", selection: $draft.formality) {
                ForEach(Formality.allCases) { Text($0.displayName).tag($0) }
            }
            Picker("Warmth", selection: $draft.warmth) {
                ForEach(WarmthLevel.allCases) { Text($0.displayName).tag($0) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Seasons").font(.subheadline).foregroundStyle(.secondary)
                SelectableChipsRow(items: Season.allCases, title: \.displayName, selection: $draft.seasons)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Styles").font(.subheadline).foregroundStyle(.secondary)
                SelectableChipsRow(items: StyleTag.allCases, title: \.displayName, selection: $draft.styles)
            }
        }

        Section("Details") {
            TextField("Brand (optional)", text: $draft.brand)
            TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                .lineLimit(1...4)
            Toggle("Favorite", isOn: $draft.isFavorite)
        }
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Color").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                // Custom color → snapped to the nearest named tag.
                ColorPicker("Custom", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: customColor) { _, newValue in snapToNearest(newValue) }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ColorTag.allCases) { tag in
                        Circle()
                            .fill(tag.color)
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                            .overlay {
                                if draft.primaryColor == tag {
                                    Circle().strokeBorder(Theme.ink, lineWidth: 3)
                                        .padding(-3)
                                }
                            }
                            .onTapGesture { draft.primaryColor = tag }
                            .accessibilityLabel(tag.displayName)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Maps an arbitrary picked color to the closest entry in the named palette,
    /// so the editorial color labels stay meaningful (reuses `ColorTag.nearest`).
    private func snapToNearest(_ color: Color) {
        guard color != .clear else { return }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        draft.primaryColor = ColorTag.nearest(red: Double(r), green: Double(g), blue: Double(b))
    }
}
