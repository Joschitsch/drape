//
//  GarmentAttributeFields.swift
//  drape
//
//  Shared attribute editor used by both the add and edit flows.
//  - inForm: true (default) — renders as Section groups, host supplies a Form
//  - inForm: false — renders as drapeCard groups, host supplies a ScrollView
//

import SwiftUI
import SwiftData

struct GarmentAttributeFields: View {
    @Binding var draft: GarmentDraft
    var inForm: Bool = true

    @Query private var profiles: [UserProfile]
    @Environment(\.modelContext) private var modelContext
    private var profile: UserProfile? { profiles.first }

    var body: some View {
        if inForm {
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

            Section("Shape & fabric") {
                field("Fit") { fitSelector }
                if draft.category == .top || draft.category == .dress {
                    field("Length") { lengthSelector }
                }
                if draft.category == .bottom {
                    field("Volume") { volumeSelector }
                }
                field("Structure") { structureSelector }
                field("Fabric weight") { weightSelector }
                field("Texture") { textureSelector }
                field("Pattern") { patternSelector }
                field("Style archetype") { archetypeSelector }
            }

            Section("Details") {
                TextField("Brand (optional)", text: $draft.brand)
                TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(1...4)
                Toggle("Favorite", isOn: $draft.isFavorite)
            }
        } else {
            VStack(spacing: 14) {
                basicsCard
                suitabilityCard
                shapeCard
                detailsCard
            }
            .padding(.horizontal, Theme.contentPadding)
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Card sections (inForm: false)

    private var basicsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Name", text: $draft.name)
                .font(Theme.body(15))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            Theme.line.frame(height: 0.5)
            cardField("Category") {
                SingleChoiceChips(items: GarmentCategory.allCases, title: \.displayName,
                                  selection: $draft.category)
            }
            Theme.line.frame(height: 0.5)
            colorRow
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
        }
        .drapeCard(radius: 14)
    }

    private var suitabilityCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            if draft.category == .footwear {
                cardField("Type") {
                    OptionalSingleChoiceChips(
                        items: FootwearSubcategory.allCases,
                        title: \.displayName,
                        selection: $draft.footwearSubcategory
                    )
                }
                Theme.line.frame(height: 0.5)
            }
            FormalityDial(formality: $draft.formality)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            Theme.line.frame(height: 0.5)
            cardField("Warmth") {
                SingleChoiceChips(items: WarmthLevel.allCases, title: \.displayName,
                                  selection: $draft.warmth)
            }
            Theme.line.frame(height: 0.5)
            cardField("Seasons") {
                SelectableChipsRow(items: Season.allCases, title: \.displayName, selection: $draft.seasons)
            }
            Theme.line.frame(height: 0.5)
            cardField("Styles") {
                StyleSelector(selection: $draft.styles,
                              customStyles: profile?.customStyles ?? [],
                              onAdd: addCustomStyle)
            }
        }
        .drapeCard(radius: 14)
    }

    private var shapeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardField("Fit") { fitSelector }
            Theme.line.frame(height: 0.5)
            if draft.category == .top || draft.category == .dress {
                cardField("Length") { lengthSelector }
                Theme.line.frame(height: 0.5)
            }
            if draft.category == .bottom {
                cardField("Volume") { volumeSelector }
                Theme.line.frame(height: 0.5)
            }
            cardField("Structure") { structureSelector }
            Theme.line.frame(height: 0.5)
            cardField("Fabric weight") { weightSelector }
            Theme.line.frame(height: 0.5)
            cardField("Texture") { textureSelector }
            Theme.line.frame(height: 0.5)
            cardField("Pattern") { patternSelector }
            Theme.line.frame(height: 0.5)
            cardField("Style archetype") { archetypeSelector }
        }
        .drapeCard(radius: 14)
    }

    // MARK: - Silhouette / fabric / pattern selectors (shared by both layouts)

    @ViewBuilder private var fitSelector: some View {
        OptionalSingleChoiceChips(items: Fit.allCases, title: \.displayName, selection: $draft.fit)
    }
    @ViewBuilder private var lengthSelector: some View {
        OptionalSingleChoiceChips(items: TopLength.allCases, title: \.displayName, selection: $draft.topLength)
    }
    @ViewBuilder private var volumeSelector: some View {
        OptionalSingleChoiceChips(items: BottomVolume.allCases, title: \.displayName, selection: $draft.bottomVolume)
    }
    @ViewBuilder private var structureSelector: some View {
        OptionalSingleChoiceChips(items: Structure.allCases, title: \.displayName, selection: $draft.structure)
    }
    @ViewBuilder private var weightSelector: some View {
        OptionalSingleChoiceChips(items: FabricWeight.allCases, title: \.displayName, selection: $draft.fabricWeight)
    }
    @ViewBuilder private var patternSelector: some View {
        OptionalSingleChoiceChips(items: PatternType.allCases, title: \.displayName, selection: $draft.patternType)
    }
    @ViewBuilder private var textureSelector: some View {
        OptionalSingleChoiceChips(items: Texture.allCases, title: \.displayName, selection: $draft.texture)
    }
    @ViewBuilder private var archetypeSelector: some View {
        OptionalSingleChoiceChips(items: Archetype.allCases, title: \.displayName, selection: $draft.archetype)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Brand (optional)", text: $draft.brand)
                .font(Theme.body(15))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            Theme.line.frame(height: 0.5)
            TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                .font(Theme.body(15))
                .lineLimit(1...4)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            Theme.line.frame(height: 0.5)
            Toggle("Favorite", isOn: $draft.isFavorite)
                .font(Theme.body(15))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .tint(Theme.ink)
        }
        .drapeCard(radius: 14)
    }

    // MARK: - Shared helpers

    private func addCustomStyle(_ style: String) {
        guard let profile, !profile.customStyles.contains(style) else { return }
        profile.customStyles.append(style)
        try? modelContext.save()
    }

    /// For Form context — labeled selector group.
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(label)
            content()
        }
        .padding(.vertical, 4)
    }

    /// For card context — labeled row with standard card padding.
    private func cardField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(label)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                MonoLabel("Color")
                Spacer()
                ColorPicker("Custom", selection: customColorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
            FlowLayout(spacing: 6) {
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
    }

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
