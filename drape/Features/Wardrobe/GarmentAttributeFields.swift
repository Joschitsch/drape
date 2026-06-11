//
//  GarmentAttributeFields.swift
//  drape
//
//  Shared Form content for editing a GarmentDraft (add + edit flows).
//

import SwiftUI
import SwiftData

/// The attribute editor used by both the add and edit screens. Renders as a set
/// of `Section`s; the host view supplies the enclosing `Form`.
struct GarmentAttributeFields: View {
    @Binding var draft: GarmentDraft

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    private var profile: UserProfile? { profiles.first }

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
            if draft.category == .footwear {
                field("Type") {
                    OptionalSingleChoiceChips(
                        items: FootwearSubcategory.allCases,
                        title: \.displayName,
                        selection: $draft.footwearSubcategory
                    )
                }
            }
            FormalityDial(formality: $draft.formality)
                .padding(.vertical, 4)
            field("Warmth") {
                SingleChoiceChips(items: WarmthLevel.allCases, title: \.displayName,
                                  selection: $draft.warmth)
            }
            field("Seasons") {
                SelectableChipsRow(items: Season.allCases, title: \.displayName, selection: $draft.seasons)
            }
            field("Styles") {
                StyleSelector(selection: $draft.styles,
                              customStyles: profile?.customStyles ?? [],
                              onAdd: addCustomStyle)
            }
        }

        Section("Details") {
            TextField("Brand (optional)", text: $draft.brand)
            TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                .lineLimit(1...4)
            Toggle("Favorite", isOn: $draft.isFavorite)
        }
    }

    /// Registers a brand-new style on the profile so it's reusable everywhere.
    private func addCustomStyle(_ style: String) {
        guard let profile, !profile.customStyles.contains(style) else { return }
        profile.customStyles.append(style)
        try? modelContext.save()
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
                // Picks an exact color: stored as-is for display; mapped to the
                // nearest named color only so the engine has a color family.
                ColorPicker("Custom", selection: customColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            FlowLayout(spacing: 6) {
                // The exact custom color shows as a leading, selected swatch.
                if let hex = draft.customColorHex {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: 2).padding(-4))
                        .frame(width: 44, height: 44)
                }
                ForEach(ColorTag.allCases) { tag in
                    SwatchButton(colorTag: tag,
                                 isSelected: draft.customColorHex == nil && draft.primaryColor == tag) {
                        draft.primaryColor = tag
                        draft.customColorHex = nil
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Reads the current display color; writing stores the exact hex and maps it
    /// to the nearest named color for the engine.
    private var customColorBinding: Binding<Color> {
        Binding(
            get: {
                draft.customColorHex.map { Color(hex: $0) } ?? draft.primaryColor.color
            },
            set: { newColor in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(newColor).getRed(&r, green: &g, blue: &b, alpha: &a)
                draft.customColorHex = String(format: "%02X%02X%02X",
                                              Int((r * 255).rounded()),
                                              Int((g * 255).rounded()),
                                              Int((b * 255).rounded()))
                draft.primaryColor = ColorTag.nearest(red: Double(r), green: Double(g), blue: Double(b))
            }
        )
    }
}
