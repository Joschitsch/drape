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
            ScrollView {
                VStack(spacing: 20) {
                    if let profile {
                        statCard
                        if !entitlements.isEnabled(.wardrobeAnalytics) {
                            proUpsellCard
                        }
                        registerCard(profile: profile)
                        occasionCard(profile: profile)
                        locationCard(profile: profile)
                        analyticsCard
                    }
                    #if DEBUG
                    subscriptionCard(entitlements: entitlements)
                    developerCard
                    #endif
                }
                .padding(.top, 20)
                .padding(.bottom, 60)
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingPaywall) {
                PaywallView().environment(entitlements)
            }
        }
    }

    // MARK: - Stats

    private var statCard: some View {
        HStack(spacing: 0) {
            statCell(value: "\(garments.count)", label: "Pieces")
            Divider()
            statCell(value: "\(outfits.count)", label: "Outfits")
            Divider()
            statCell(value: "\(garments.reduce(0) { $0 + $1.wearCount })", label: "Wears")
        }
        .frame(maxWidth: .infinity)
        .drapeCard(radius: 14)
        .padding(.horizontal, Theme.contentPadding)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 5) {
            SerifText(value, size: 28)
            MonoLabel(label, size: 9.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }

    // MARK: - Pro upsell

    private var proUpsellCard: some View {
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
        .padding(.horizontal, Theme.contentPadding)
    }

    // MARK: - Register

    private func registerCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                MonoLabel("Your register")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("Styles you lean on", size: 9.5)
                    StyleSelector(selection: stylesBinding(profile))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
            Text("Outfits featuring these styles are scored higher.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, Theme.contentPadding)
        }
    }

    // MARK: - Occasion preferences

    private func occasionCard(profile: UserProfile) -> some View {
        let occasions = OnboardingViewModel.occasions
        return VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                MonoLabel("Occasion preferences")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                ForEach(Array(occasions.enumerated()), id: \.element.id) { idx, occasion in
                    DisclosureGroup {
                        OccasionPreferenceEditor(
                            occasion: occasion,
                            formality: occasionFormalityBinding(profile, occasion),
                            styles: occasionStylesBinding(profile, occasion)
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    } label: {
                        Label(occasion.displayName, image: occasion.iconName)
                            .labelStyle(.drapeIcon)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                    }
                    .padding(.trailing, 16)
                    if idx < occasions.count - 1 {
                        Theme.line.frame(height: 0.5)
                    }
                }
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
        }
    }

    // MARK: - Location

    private func locationCard(profile: UserProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                MonoLabel("Location")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                HStack {
                    Text("Home")
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text(locationLabel(profile))
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.inkSoft)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)

                Theme.line.frame(height: 0.5)

                Button {
                    Task { await useCurrentLocation(profile) }
                } label: {
                    HStack {
                        Label("Use current location", systemImage: "location.fill")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        if fetchingLocation { Spacer(); ProgressView().controlSize(.small) }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .disabled(fetchingLocation)

                if profile.homeLatitude != nil {
                    Theme.line.frame(height: 0.5)
                    Button("Clear home location") {
                        profile.homeLatitude = nil
                        profile.homeLongitude = nil
                        profile.homeCity = nil
                        persist()
                    }
                    .font(Theme.body(15))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
                }
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
            Text("Used for weather when live location is unavailable.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, Theme.contentPadding)
        }
    }

    // MARK: - Analytics

    private var analyticsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                MonoLabel("Pro analytics")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                if entitlements.isEnabled(.wardrobeAnalytics) {
                    NavigationLink {
                        WardrobeAnalyticsView()
                    } label: {
                        HStack {
                            Label("Wardrobe Analytics", image: "drape.analytics")
                                .labelStyle(.drapeIcon)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(Theme.inkFaint)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                }
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
        }
    }

    // MARK: - Subscription (debug only)

    #if DEBUG
    @ViewBuilder
    private func subscriptionCard(entitlements: MockEntitlementService) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Subscription")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                Picker("Tier", selection: Bindable(entitlements).tier) {
                    ForEach(SubscriptionTier.allCases) { tier in
                        Text(tier.displayName).tag(tier)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                Text(entitlements.tier == .pro
                     ? "Pro features unlocked."
                     : "Free tier — up to \(SubscriptionTier.free.garmentLimit ?? 0) items.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.inkSoft)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                if entitlements.tier == .free {
                    Theme.line.frame(height: 0.5)
                    Button("Upgrade to Pro") { showingPaywall = true }
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
            Text("Dev toggle — not visible in release builds.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, Theme.contentPadding)
        }
    }

    @ViewBuilder
    private var developerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 0) {
                MonoLabel("Developer")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                Theme.line.frame(height: 0.5)
                NavigationLink {
                    DebugHarnessView()
                } label: {
                    HStack {
                        Text("Attribute & engine harness")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                Theme.line.frame(height: 0.5)
                NavigationLink {
                    DebugGroundTruthView()
                } label: {
                    HStack {
                        Text("Ground-truth review & export")
                            .font(Theme.body(15))
                            .foregroundStyle(Theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Theme.inkSoft)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .drapeCard(radius: 14)
            .padding(.horizontal, Theme.contentPadding)
            Text("Imports test wardrobes, scores autofill, runs the engine playground, and reviews real-garment autofill against ground truth. Debug builds only.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.inkSoft)
                .padding(.horizontal, Theme.contentPadding)
        }
    }
    #endif

    // MARK: - Bindings (edit-in-place, auto-saving)

    private func persist() { try? modelContext.save() }

    private func stylesBinding(_ profile: UserProfile) -> Binding<Set<String>> {
        Binding(
            get: { Set(profile.preferredStyles) },
            set: { profile.preferredStyles = $0.sorted(); persist() }
        )
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
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
