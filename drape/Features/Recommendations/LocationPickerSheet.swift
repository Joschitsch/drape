//
//  LocationPickerSheet.swift
//  drape
//
//  Lets the Style tab plan looks for somewhere other than the current location:
//  a city search plus quick rows for the current location and the saved Home.
//

import SwiftUI

struct LocationPickerSheet: View {
    /// The currently planned override, if any — shown with a checkmark. nil means
    /// the tab is on the live/current location.
    let planned: PlaceSuggestion?
    /// Saved home city + coordinate, offered as a quick row when available.
    let home: PlaceSuggestion?
    /// Called with the chosen place, or nil to revert to the current location.
    let onSelect: (PlaceSuggestion?) -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var results: [PlaceSuggestion] = []
    @State private var isSearching = false

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    quickRow(
                        title: "Use current location",
                        systemImage: "location.fill",
                        isActive: planned == nil
                    ) { choose(nil) }

                    if let home {
                        quickRow(
                            title: home.name,
                            subtitle: "Home",
                            systemImage: "house",
                            isActive: planned == home
                        ) { choose(home) }
                    }
                }

                if !trimmedQuery.isEmpty {
                    Section {
                        if isSearching && results.isEmpty {
                            HStack {
                                ProgressView().controlSize(.small)
                                Text("Searching…")
                                    .font(Theme.body(13))
                                    .foregroundStyle(Theme.inkSoft)
                            }
                        } else if results.isEmpty {
                            Text("No places found")
                                .font(Theme.body(13))
                                .foregroundStyle(Theme.inkSoft)
                        } else {
                            ForEach(results) { place in
                                quickRow(
                                    title: place.name,
                                    systemImage: "mappin.and.ellipse",
                                    isActive: planned == place
                                ) { choose(place) }
                            }
                        }
                    } header: {
                        Text("Results")
                    }
                }
            }
            .navigationTitle("Plan for a place")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search a city")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: searchText) { await runSearch() }
        }
    }

    private func quickRow(
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.inkSoft)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.body(15))
                        .foregroundStyle(Theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(Theme.mono(10, weight: .medium))
                            .foregroundStyle(Theme.inkSoft)
                    }
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func choose(_ place: PlaceSuggestion?) {
        onSelect(place)
        dismiss()
    }

    /// Debounced forward search; cancels naturally when `searchText` changes
    /// (the `.task(id:)` is torn down and re-run).
    private func runSearch() async {
        let query = trimmedQuery
        guard !query.isEmpty else {
            results = []
            isSearching = false
            return
        }
        isSearching = true
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        let found = await container.location.search(query: query)
        guard !Task.isCancelled else { return }
        results = found
        isSearching = false
    }
}

#Preview {
    let container = AppContainer.preview()
    return LocationPickerSheet(
        planned: nil,
        home: PlaceSuggestion(name: "Berlin", coordinate: Coordinate(latitude: 52.52, longitude: 13.405)),
        onSelect: { _ in }
    )
    .environment(container)
}
