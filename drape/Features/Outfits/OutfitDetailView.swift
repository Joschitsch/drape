//
//  OutfitDetailView.swift
//  drape
//
//  Full view of a saved outfit, with wear logging, edit and delete.
//

import SwiftUI
import SwiftData

struct OutfitDetailView: View {
    @Bindable var outfit: Outfit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var showWearConfirmation = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: Theme.tileSpacing)]

    private var lastWorn: Date? {
        outfit.wearEvents.map(\.date).max()
    }

    var body: some View {
        List {
            Section {
                LazyVGrid(columns: columns, spacing: Theme.tileSpacing) {
                    ForEach(outfit.garments) { garment in
                        NavigationLink(value: garment) {
                            GarmentTile(garment: garment)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
            }

            Section("Details") {
                LabeledContent("Occasion", value: outfit.occasion.displayName)
                if !outfit.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack { ForEach(outfit.tags, id: \.self) { TagChip($0) } }
                    }
                }
                LabeledContent("Times worn", value: "\(outfit.wearCount)")
                if let lastWorn {
                    LabeledContent("Last worn", value: lastWorn.formatted(date: .abbreviated, time: .omitted))
                }
            }

            Section {
                Button {
                    logWear()
                } label: {
                    Label("Wore Today", systemImage: "checkmark.circle")
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Outfit", systemImage: "trash")
                }
            }
        }
        .navigationTitle(outfit.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            OutfitBuilderView(editing: outfit)
        }
        .confirmationDialog("Delete this outfit?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Logged today's wear", isPresented: $showWearConfirmation) {
            Button("OK", role: .cancel) {}
        }
    }

    private func logWear() {
        let event = WearEvent(date: .now, outfit: outfit, garments: outfit.garments)
        modelContext.insert(event)
        try? modelContext.save()
        showWearConfirmation = true
    }

    private func delete() {
        modelContext.delete(outfit)
        try? modelContext.save()
        dismiss()
    }
}
