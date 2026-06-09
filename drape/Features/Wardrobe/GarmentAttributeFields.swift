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
            field("Category") {
                SingleChoiceChips(items: GarmentCategory.allCases, title: \.displayName,
                                  selection: $draft.category)
            }
            colorRow
        }

        Section("Suitability") {
            field("Formality") {
                SingleChoiceChips(items: Formality.allCases, title: \.displayName,
                                  selection: $draft.formality)
            }
            field("Warmth") {
                SingleChoiceChips(items: WarmthLevel.allCases, title: \.displayName,
                                  selection: $draft.warmth)
            }
            field("Seasons") {
                SelectableChipsRow(items: Season.allCases, title: \.displayName, selection: $draft.seasons)
            }
            field("Styles") {
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

    /// A labeled selector group — one consistent layout for every chip/swatch field.
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(label)
            content()
        }
        .padding(.vertical, 4)
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("Color")
                Spacer()
                // Custom color → snapped to the nearest named tag.
                ColorPicker("Custom", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: customColor) { _, newValue in snapToNearest(newValue) }
            }
            FlowLayout(spacing: 6) {
                ForEach(ColorTag.allCases) { tag in
                    SwatchButton(colorTag: tag, isSelected: draft.primaryColor == tag) {
                        draft.primaryColor = tag
                    }
                }
            }
        }
        .padding(.vertical, 4)
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
