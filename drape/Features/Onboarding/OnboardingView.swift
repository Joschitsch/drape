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
                    Capsule().fill(Color(.systemFill))
                    Capsule().fill(Color.accentColor)
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
                } else {
                    let occasion = OnboardingViewModel.occasions[model.currentStep - 1]
                    occasionStep(occasion)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut, value: model.currentStep)

            // Navigation buttons
            HStack {
                if model.currentStep > 0 {
                    Button("Back") { model.back() }
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.isOnLastStep ? "Let's go" : "Next") {
                    if model.isOnLastStep {
                        model.apply(to: profile)
                        try? modelContext.save()
                    } else {
                        model.next()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "tshirt.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to Drape")
                .font(.largeTitle.bold())
            Text("Let's personalise your outfit recommendations.\nTell us how you like to dress for different occasions.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
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
            onUpdate: { formality, styles in
                model.update(occasion: occasion, formality: formality, styles: styles)
            }
        )
    }

    private var globalStyleStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your overall style")
                    .font(.title2.bold())
                    .padding(.horizontal, 24)
                Text("Any general styles you love? Used as a fallback for occasions you skipped.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
            .padding(.top, 32)

            GlobalStylePicker(selected: $model.globalStyles)
                .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Wrappers to hold local state per step

private struct OccasionPreferenceStepWrapper: View {
    let occasion: Occasion
    @State var formality: Formality
    @State var styles: Set<StyleTag>
    let onUpdate: (Formality, Set<StyleTag>) -> Void

    init(occasion: Occasion, initialFormality: Formality, initialStyles: Set<StyleTag>, onUpdate: @escaping (Formality, Set<StyleTag>) -> Void) {
        self.occasion = occasion
        self._formality = State(initialValue: initialFormality)
        self._styles = State(initialValue: initialStyles)
        self.onUpdate = onUpdate
    }

    var body: some View {
        OccasionPreferenceStep(occasion: occasion, formality: $formality, styles: $styles)
            .onChange(of: formality) { _, new in onUpdate(new, styles) }
            .onChange(of: styles) { _, new in onUpdate(formality, new) }
    }
}

private struct GlobalStylePicker: View {
    @Binding var selected: Set<StyleTag>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(StyleTag.allCases) { tag in
                let isSelected = selected.contains(tag)
                Button {
                    if isSelected { selected.remove(tag) } else { selected.insert(tag) }
                } label: {
                    Text(tag.displayName)
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(isSelected ? Color.accentColor : Color(.secondarySystemBackground),
                                    in: Capsule())
                        .foregroundStyle(isSelected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
