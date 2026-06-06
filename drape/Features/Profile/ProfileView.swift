//
//  ProfileView.swift
//  drape
//
//  Profile editing: per-occasion prefs, global styles/colors/formality,
//  home location, Pro-gated analytics, and the dev tier toggle.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(MockEntitlementService.self) private var entitlements
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var editingOccasion: Occasion? = nil
    @State private var showingStyleEdit = false
    @State private var showingColorEdit = false
    @State private var showingFormalityEdit = false
    @State private var showingLocationEdit = false
    @State private var showingPaywall = false

    @Query(filter: #Predicate<Garment> { !$0.isArchived }) private var garments: [Garment]
    @Query private var outfits: [Outfit]

    var body: some View {
        @Bindable var entitlements = entitlements
        return NavigationStack {
            Form {
                if let profile {
                    statCardSection
                    registerSection(profile: profile)
                    if !entitlements.isEnabled(.wardrobeAnalytics) {
                        proUpsellSection
                    }
                    occasionSection(profile: profile)
                    globalStyleSection(profile: profile)
                    colorSection(profile: profile)
                    formalitySection(profile: profile)
                    locationSection(profile: profile)
                    analyticsSection
                }
                subscriptionSection(entitlements: entitlements)
            }
            .navigationTitle("Profile")
            .sheet(item: $editingOccasion) { occasion in
                if let profile {
                    OccasionEditSheet(occasion: occasion, profile: profile)
                        .environment(\.modelContext, modelContext)
                }
            }
            .sheet(isPresented: $showingStyleEdit) {
                if let profile { StyleEditSheet(profile: profile).environment(\.modelContext, modelContext) }
            }
            .sheet(isPresented: $showingColorEdit) {
                if let profile { ColorEditSheet(profile: profile).environment(\.modelContext, modelContext) }
            }
            .sheet(isPresented: $showingFormalityEdit) {
                if let profile { FormalityEditSheet(profile: profile).environment(\.modelContext, modelContext) }
            }
            .sheet(isPresented: $showingLocationEdit) {
                if let profile { LocationEditSheet(profile: profile).environment(\.modelContext, modelContext) }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView().environment(entitlements)
            }
        }
    }

    // MARK: - Sections

    private var statCardSection: some View {
        Section {
            HStack(spacing: 0) {
                statCell(value: "\(garments.count)", label: "Pieces")
                Divider()
                statCell(value: "\(outfits.count)", label: "Outfits")
                Divider()
                statCell(value: "\(garments.reduce(0) { $0 + $1.wearCount })", label: "Wears")
            }
            .frame(maxWidth: .infinity)
        }
        .listRowInsets(.init())
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
            Text(label.uppercased())
                .font(.caption2)
                .foregroundStyle(Theme.inkFaint)
                .kerning(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    private func registerSection(profile: UserProfile) -> some View {
        Section("Your register") {
            if !profile.preferredStyles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(profile.preferredStyles, id: \.self) { style in
                            Text(style.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 7)
                                .background(Theme.surface)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 0.5))
                        }
                    }
                }
            }
            if !profile.preferredColors.isEmpty {
                HStack(spacing: 10) {
                    Text("Palette")
                        .font(.caption)
                        .foregroundStyle(Theme.inkFaint)
                    ForEach(profile.preferredColors, id: \.self) { color in
                        Circle()
                            .fill(color.color)
                            .frame(width: 22, height: 22)
                            .overlay(Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5))
                    }
                }
            }
        }
    }

    private var proUpsellSection: some View {
        Section {
            Button { showingPaywall = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Drape Pro · 3.99/month")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                    Text("Become the version of yourself you already own the clothes for.")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text("See what's inside")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
    }

    private func occasionSection(profile: UserProfile) -> some View {
        Section("Occasion preferences") {
            ForEach(OnboardingViewModel.occasions) { occasion in
                let pref = profile.preference(for: occasion)
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Formality")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(pref?.targetFormality.displayName ?? occasion.targetFormality.displayName)
                        }
                        if let styles = pref?.styles, !styles.isEmpty {
                            chips(styles.map(\.displayName))
                        } else {
                            Text("No styles set")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        Button("Edit") { editingOccasion = occasion }
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Label(occasion.displayName, systemImage: occasion.systemImage)
                }
            }
        }
    }

    private func globalStyleSection(profile: UserProfile) -> some View {
        Section("Global style fallback") {
            if profile.preferredStyles.isEmpty {
                Text("None set")
                    .foregroundStyle(.secondary)
            } else {
                chips(profile.preferredStyles.map(\.displayName))
            }
            Button("Edit styles") { showingStyleEdit = true }
                .font(.footnote)
        }
    }

    private func colorSection(profile: UserProfile) -> some View {
        Section("Preferred colors") {
            if profile.preferredColors.isEmpty {
                Text("None set")
                    .foregroundStyle(.secondary)
            } else {
                chips(profile.preferredColors.map(\.displayName),
                      swatches: profile.preferredColors.map(\.color))
            }
            Button("Edit colors") { showingColorEdit = true }
                .font(.footnote)
        }
    }

    private func formalitySection(profile: UserProfile) -> some View {
        Section("Default formality") {
            HStack {
                Text(profile.defaultFormality.displayName)
                Spacer()
                Button("Edit") { showingFormalityEdit = true }
                    .font(.footnote)
            }
        }
    }

    private func locationSection(profile: UserProfile) -> some View {
        Section {
            if let lat = profile.homeLatitude, let lon = profile.homeLongitude {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Home location set")
                        Text(String(format: "%.4f, %.4f", lat, lon))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Edit") { showingLocationEdit = true }
                        .font(.footnote)
                }
            } else {
                Button("Set home location") { showingLocationEdit = true }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Used for weather when live location is unavailable.")
        }
    }

    private var analyticsSection: some View {
        Section("Pro analytics") {
            if entitlements.isEnabled(.wardrobeAnalytics) {
                NavigationLink("Wardrobe Analytics") {
                    WardrobeAnalyticsView()
                }
            } else {
                Button {
                    showingPaywall = true
                } label: {
                    HStack {
                        Label("Wardrobe Analytics", systemImage: "chart.bar.fill")
                        Spacer()
                        Text("Pro")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.yellow.opacity(0.2))
                            .foregroundStyle(.yellow)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func subscriptionSection(entitlements: MockEntitlementService) -> some View {
        Section {
            Picker("Tier", selection: Bindable(entitlements).tier) {
                ForEach(SubscriptionTier.allCases) { tier in
                    Text(tier.displayName).tag(tier)
                }
            }
            .pickerStyle(.segmented)
            Text(entitlements.tier == .pro
                 ? "Pro features unlocked."
                 : "Free tier — up to \(SubscriptionTier.free.garmentLimit ?? 0) items.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if entitlements.tier == .free {
                Button("Upgrade to Pro") { showingPaywall = true }
            }
        } header: {
            Text("Subscription")
        } footer: {
            Text("Dev toggle — real purchasing is added in Step 6.")
        }
    }

    // MARK: - Helpers

    private func chips(_ labels: [String], swatches: [Color]? = nil) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(Array(labels.enumerated()), id: \.offset) { offset, label in
                    TagChip(label, swatch: swatches?[safe: offset])
                }
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Occasion edit sheet

private struct OccasionEditSheet: View {
    let occasion: Occasion
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var formality: Formality
    @State private var styles: Set<StyleTag>

    init(occasion: Occasion, profile: UserProfile) {
        self.occasion = occasion
        self.profile = profile
        let existing = profile.preference(for: occasion)
        _formality = State(initialValue: existing?.targetFormality ?? occasion.targetFormality)
        _styles = State(initialValue: Set(existing?.styles ?? []))
    }

    var body: some View {
        NavigationStack {
            OccasionPreferenceStep(occasion: occasion, formality: $formality, styles: $styles)
                .navigationTitle(occasion.displayName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            var prefs = profile.occasionPreferences.filter { $0.occasion != occasion }
                            prefs.append(OccasionPreference(occasion: occasion, targetFormality: formality, styles: Array(styles)))
                            profile.occasionPreferences = prefs
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Style edit sheet

private struct StyleEditSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<StyleTag>

    init(profile: UserProfile) {
        self.profile = profile
        _selection = State(initialValue: Set(profile.preferredStyles))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Choose your global style defaults") {
                    SelectableChipsRow(
                        items: StyleTag.allCases,
                        title: \.displayName,
                        selection: $selection
                    )
                }
            }
            .navigationTitle("Global Styles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.preferredStyles = Array(selection)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Color edit sheet

private struct ColorEditSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selection: Set<ColorTag>

    init(profile: UserProfile) {
        self.profile = profile
        _selection = State(initialValue: Set(profile.preferredColors))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Colors you gravitate toward") {
                    SelectableChipsRow(
                        items: ColorTag.allCases,
                        title: \.displayName,
                        selection: $selection
                    )
                }
            }
            .navigationTitle("Preferred Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.preferredColors = Array(selection)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Formality edit sheet

private struct FormalityEditSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var formality: Formality

    init(profile: UserProfile) {
        self.profile = profile
        _formality = State(initialValue: profile.defaultFormality)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your default dress level") {
                    Picker("Formality", selection: $formality) {
                        ForEach(Formality.allCases) { f in
                            Text(f.displayName).tag(f)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Default Formality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        profile.defaultFormality = formality
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Location edit sheet

private struct LocationEditSheet: View {
    let profile: UserProfile
    @Environment(\.modelContext) private var modelContext
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var latText: String
    @State private var lonText: String
    @State private var isFetching = false
    @State private var fetchError: String? = nil

    init(profile: UserProfile) {
        self.profile = profile
        _latText = State(initialValue: profile.homeLatitude.map { String(format: "%.6f", $0) } ?? "")
        _lonText = State(initialValue: profile.homeLongitude.map { String(format: "%.6f", $0) } ?? "")
    }

    private var parsedCoords: (Double, Double)? {
        guard let lat = Double(latText), let lon = Double(lonText),
              (-90...90).contains(lat), (-180...180).contains(lon) else { return nil }
        return (lat, lon)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Latitude") {
                        TextField("e.g. 48.8566", text: $latText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Longitude") {
                        TextField("e.g. 2.3522", text: $lonText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("Home coordinates")
                } footer: {
                    if let err = fetchError {
                        Text(err).foregroundStyle(.red)
                    } else {
                        Text("Used as a weather fallback when live location is off.")
                    }
                }

                Section {
                    Button {
                        fetchCurrentLocation()
                    } label: {
                        HStack {
                            Label("Use current location", systemImage: "location.fill")
                            if isFetching {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isFetching)
                }

                if profile.homeLatitude != nil {
                    Section {
                        Button("Clear home location", role: .destructive) {
                            profile.homeLatitude = nil
                            profile.homeLongitude = nil
                            try? modelContext.save()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Home Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let (lat, lon) = parsedCoords else { return }
                        profile.homeLatitude = lat
                        profile.homeLongitude = lon
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(parsedCoords == nil)
                }
            }
        }
    }

    private func fetchCurrentLocation() {
        isFetching = true
        fetchError = nil
        Task {
            do {
                let coord = try await container.location.currentCoordinate()
                await MainActor.run {
                    latText = String(format: "%.6f", coord.latitude)
                    lonText = String(format: "%.6f", coord.longitude)
                    isFetching = false
                }
            } catch {
                await MainActor.run {
                    fetchError = "Could not get location: \(error.localizedDescription)"
                    isFetching = false
                }
            }
        }
    }
}

#Preview {
    let container = AppContainer.preview()
    ProfileView()
        .modelContainer(.previewContainer())
        .environment(container)
        .environment(container.entitlements)
}
