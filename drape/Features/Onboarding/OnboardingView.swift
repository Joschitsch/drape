//
//  OnboardingView.swift
//  drape
//
//  FTU flow: collects per-occasion style preferences before the main app.
//

import SwiftUI
import SwiftData

struct OnboardingView: View {
    @State private var model = OnboardingViewModel()
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                let progress = Double(model.currentStep + 1) / Double(model.totalSteps)
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.line)
                    Capsule().fill(Theme.ink)
                        .frame(width: geo.size.width * progress)
                }
                .frame(height: 4)
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            // Step content
            Group {
                if model.currentStep == 0 {
                    welcomeStep
                } else if model.currentStep == model.totalSteps - 1 {
                    globalStyleStep
                } else if model.currentStep == model.appetitesStep {
                    appetitesStep
                } else {
                    let occasion = OnboardingViewModel.occasions[model.currentStep - 1]
                    occasionStep(occasion)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.drapeReveal, value: model.currentStep)

            // Navigation buttons
            HStack {
                if model.currentStep > 0 {
                    Button { model.back() } label: {
                        Text("Back")
                            .font(Theme.body(17))
                            .foregroundStyle(Theme.inkSoft)
                            .frame(minHeight: 44)
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    if model.isOnLastStep {
                        model.apply(to: profile)
                        try? modelContext.save()
                    } else {
                        model.next()
                    }
                } label: {
                    Text(model.isOnLastStep ? "Let's go" : "Next")
                        .font(Theme.body(17, weight: .semibold))
                        .foregroundStyle(Theme.paper)
                        .frame(minHeight: 50)
                        .padding(.horizontal, 28)
                        .background(Theme.ink, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .background(Theme.paper.ignoresSafeArea())
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image("drape.wardrobe")
                .font(.system(size: 56))
                .foregroundStyle(Theme.ink)
            MonoLabel("Welcome to Drape")
            SerifText("Become the version of yourself you already own the clothes for.", size: 28)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
            Text("Tell us how you like to dress for a few occasions, and Drape will read your wardrobe, the weather, and your week.")
                .font(Theme.body(15))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    private func occasionStep(_ occasion: Occasion) -> some View {
        let draft = model.draft(for: occasion)
        return OccasionPreferenceStepWrapper(
            occasion: occasion,
            initialFormality: draft.targetFormality,
            initialStyles: Set(draft.styles),
            customStyles: profile.customStyles,
            onAddStyle: addCustomStyle,
            onUpdate: { formality, styles in
                model.update(occasion: occasion, formality: formality, styles: styles)
            }
        )
    }

    private var appetitesStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    SerifText("A few style instincts", size: 24)
                    Text("These set sensible defaults. Drape keeps learning from your thumbs as you go.")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkSoft)
                }

                appetiteField("Color") {
                    SingleChoiceChips(items: ColorAppetite.allCases, title: \.displayName,
                                      selection: Bindable(model).tuning.colorAppetite)
                }
                appetiteField("Patterns") {
                    SingleChoiceChips(items: PatternTolerance.allCases, title: \.displayName,
                                      selection: Bindable(model).tuning.patternTolerance)
                }
                appetiteField("Silhouette") {
                    SingleChoiceChips(items: SilhouettePreference.allCases, title: \.displayName,
                                      selection: Bindable(model).tuning.silhouette)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
        }
    }

    private func appetiteField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel(label)
            content()
        }
    }

    private var globalStyleStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                SerifText("Your overall style", size: 24)
                    .padding(.horizontal, 24)
                Text("Any general styles you love? Used as a fallback for occasions you skipped.")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 32)

            GlobalStylePicker(selected: $model.globalStyles,
                              customStyles: profile.customStyles,
                              onAdd: addCustomStyle)
                .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func addCustomStyle(_ style: String) {
        guard !profile.customStyles.contains(style) else { return }
        profile.customStyles.append(style)
        try? modelContext.save()
    }
}

// MARK: - Wrappers to hold local state per step

private struct OccasionPreferenceStepWrapper: View {
    let occasion: Occasion
    @State var formality: Formality
    @State var styles: Set<String>
    let customStyles: [String]
    let onAddStyle: (String) -> Void
    let onUpdate: (Formality, Set<String>) -> Void

    init(occasion: Occasion, initialFormality: Formality, initialStyles: Set<String>,
         customStyles: [String], onAddStyle: @escaping (String) -> Void,
         onUpdate: @escaping (Formality, Set<String>) -> Void) {
        self.occasion = occasion
        self._formality = State(initialValue: initialFormality)
        self._styles = State(initialValue: initialStyles)
        self.customStyles = customStyles
        self.onAddStyle = onAddStyle
        self.onUpdate = onUpdate
    }

    var body: some View {
        OccasionPreferenceStep(occasion: occasion, formality: $formality, styles: $styles,
                               customStyles: customStyles, onAddStyle: onAddStyle)
            .onChange(of: formality) { _, new in onUpdate(new, styles) }
            .onChange(of: styles) { _, new in onUpdate(formality, new) }
    }
}

private struct GlobalStylePicker: View {
    @Binding var selected: Set<String>
    var customStyles: [String]
    var onAdd: (String) -> Void

    var body: some View {
        StyleSelector(selection: $selected, customStyles: customStyles, onAdd: onAdd)
    }
}
