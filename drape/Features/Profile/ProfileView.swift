//
//  ProfileView.swift
//  drape
//
//  Profile: stats, register (styles + palette), per-occasion prefs, default
//  formality, home location, Pro-gated analytics, dev tier toggle. Everything is
//  edited in place — chips/swatches/pickers apply immediately (auto-save), so
//  there are no separate editor sheets.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Query private var profiles: [UserProfile]
    @Environment(MockEntitlementService.self) private var entitlements
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext

    private var profile: UserProfile? { profiles.first }

    @State private var showingPaywall = false
    @State private var fetchingLocation = false

    @Query(filter: #Predicate<Garment> { !$0.isArchived }) private var garments: [Garment]
    @Query private var outfits: [Outfit]

    var body: some View {
        @Bindable var entitlements = entitlements
        return NavigationStack {
            Form {
                if let profile {
                    statCardSection
                    if !entitlements.isEnabled(.wardrobeAnalytics) {
                        proUpsellSection
                    }
                    registerSection(profile: profile)
                    occasionSection(profile: profile)
                    locationSection(profile: profile)
                    analyticsSection
                }
                subscriptionSection(entitlements: entitlements)
            }
            .navigationTitle("Profile")
            .scrollContentBackground(.hidden)
            .background(Theme.paper)
            .sheet(isPresented: $showingPaywall) {
                PaywallView().environment(entitlements)
            }
        }
    }

    // MARK: - Stats

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
        VStack(spacing: 5) {
            SerifText(value, size: 28)
            MonoLabel(label, size: 9.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Register (styles + palette) — edited in place

    private func registerSection(profile: UserProfile) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                MonoLabel("Styles you lean on")
                StyleSelector(selection: stylesBinding(profile),
                              customStyles: profile.customStyles,
                              onAdd: { addCustomStyle($0, profile) })
            }
            .padding(.vertical, 4)
        } header: {
            Text("Your register")
        } footer: {
            Text("Outfits featuring these styles are scored higher.")
        }
    }

    // MARK: - Occasion preferences — inline disclosure editor

    private func occasionSection(profile: UserProfile) -> some View {
        Section("Occasion preferences") {
            ForEach(OnboardingViewModel.occasions) { occasion in
                DisclosureGroup {
                    OccasionPreferenceEditor(
                        occasion: occasion,
                        formality: occasionFormalityBinding(profile, occasion),
                        styles: occasionStylesBinding(profile, occasion),
                        customStyles: profile.customStyles,
                        onAddStyle: { addCustomStyle($0, profile) }
                    )
                    .padding(.vertical, 8)
                } label: {
                    Label(occasion.displayName, image: occasion.iconName)
                        .labelStyle(.drapeIcon)
                }
            }
        }
    }

    // MARK: - Location — inline

    private func locationSection(profile: UserProfile) -> some View {
        Section {
            HStack {
                Text("Home")
                Spacer()
                Text(locationLabel(profile)).foregroundStyle(Theme.inkSoft)
            }
            Button {
                Task { await useCurrentLocation(profile) }
            } label: {
                HStack {
                    Label("Use current location", systemImage: "location.fill")
                    if fetchingLocation { Spacer(); ProgressView() }
                }
            }
            .disabled(fetchingLocation)
            if profile.homeLatitude != nil {
                Button("Clear home location", role: .destructive) {
                    profile.homeLatitude = nil
                    profile.homeLongitude = nil
                    profile.homeCity = nil
                    persist()
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("Used for weather when live location is unavailable.")
        }
    }

    // MARK: - Analytics + Pro

    private var proUpsellSection: some View {
        Section {
            Button { showingPaywall = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    MonoLabel("Drape Pro · 3.99 / month", color: Theme.paper.opacity(0.6))
                    SerifText("Become the version of yourself you already own the clothes for.",
                              size: 20, color: Theme.paper)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 7) {
                        MonoLabel("See what's inside", color: Theme.paper)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(Theme.paper)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
        .listRowInsets(.init())
        .listRowBackground(Color.clear)
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
                        Label("Wardrobe Analytics", image: "drape.analytics")
                            .labelStyle(.drapeIcon)
                        Spacer()
                        Text("Pro")
                            .font(Theme.mono(10, weight: .medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Theme.ink, in: Capsule())
                            .foregroundStyle(Theme.paper)
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
                .foregroundStyle(Theme.inkSoft)
            if entitlements.tier == .free {
                Button("Upgrade to Pro") { showingPaywall = true }
            }
        } header: {
            Text("Subscription")
        } footer: {
            Text("Dev toggle — real purchasing is added in Step 6.")
        }
    }

    // MARK: - Bindings (edit-in-place, auto-saving)

    private func persist() { try? modelContext.save() }

    private func stylesBinding(_ profile: UserProfile) -> Binding<Set<String>> {
        Binding(
            get: { Set(profile.preferredStyles) },
            set: { profile.preferredStyles = $0.sorted(); persist() }
        )
    }

    /// Registers a brand-new style on the profile so it's reusable everywhere.
    private func addCustomStyle(_ style: String, _ profile: UserProfile) {
        guard !profile.customStyles.contains(style) else { return }
        profile.customStyles.append(style)
        persist()
    }

    private func occasionFormalityBinding(_ profile: UserProfile, _ occasion: Occasion) -> Binding<Formality> {
        Binding(
            get: { profile.preference(for: occasion)?.targetFormality ?? occasion.targetFormality },
            set: { setOccasion(profile, occasion, formality: $0, styles: nil) }
        )
    }

    private func occasionStylesBinding(_ profile: UserProfile, _ occasion: Occasion) -> Binding<Set<String>> {
        Binding(
            get: { Set(profile.preference(for: occasion)?.styles ?? []) },
            set: { setOccasion(profile, occasion, formality: nil, styles: $0) }
        )
    }

    private func setOccasion(_ profile: UserProfile, _ occasion: Occasion,
                             formality: Formality?, styles: Set<String>?) {
        let existing = profile.preference(for: occasion)
        let newFormality = formality ?? existing?.targetFormality ?? occasion.targetFormality
        let newStyles = styles.map { $0.sorted() } ?? existing?.styles ?? []
        var prefs = profile.occasionPreferences.filter { $0.occasion != occasion }
        prefs.append(OccasionPreference(occasion: occasion, targetFormality: newFormality, styles: newStyles))
        profile.occasionPreferences = prefs
        persist()
    }

    // MARK: - Location helpers

    private func locationLabel(_ profile: UserProfile) -> String {
        if let city = profile.homeCity, !city.isEmpty { return city }
        if let lat = profile.homeLatitude, let lon = profile.homeLongitude {
            return String(format: "%.3f, %.3f", lat, lon)
        }
        return "Not set"
    }

    private func useCurrentLocation(_ profile: UserProfile) async {
        fetchingLocation = true
        defer { fetchingLocation = false }
        do {
            let coord = try await container.location.currentCoordinate()
            profile.homeLatitude = coord.latitude
            profile.homeLongitude = coord.longitude
            profile.homeCity = await container.location.placeName(for: coord)
            persist()
        } catch {
            // Leave the existing location in place on failure.
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
