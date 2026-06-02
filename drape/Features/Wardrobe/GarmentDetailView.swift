//
//  GarmentDetailView.swift
//  drape
//
//  Full view of a garment with edit, favorite and delete.
//

import SwiftUI
import SwiftData

struct GarmentDetailView: View {
    @Bindable var garment: Garment

    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section {
                NormalizedImageView(assetID: garment.imageAssetID, category: garment.category, useThumbnail: false)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .listRowBackground(Color.clear)
            }

            Section("Attributes") {
                LabeledContent("Color") {
                    HStack(spacing: 6) {
                        Circle().fill(garment.primaryColor.color).frame(width: 14, height: 14)
                            .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
                        Text(garment.primaryColor.displayName)
                    }
                }
                LabeledContent("Formality", value: garment.formality.displayName)
                LabeledContent("Warmth", value: garment.warmth.displayName)
                if !garment.seasons.isEmpty {
                    LabeledContent("Seasons", value: garment.seasons.map(\.displayName).joined(separator: ", "))
                }
                if !garment.styles.isEmpty {
                    LabeledContent("Styles", value: garment.styles.map(\.displayName).joined(separator: ", "))
                }
                if let brand = garment.brand, !brand.isEmpty {
                    LabeledContent("Brand", value: brand)
                }
                LabeledContent("Times worn", value: "\(garment.wearCount)")
            }

            if let notes = garment.notes, !notes.isEmpty {
                Section("Notes") { Text(notes) }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete Item", systemImage: "trash")
                }
            }
        }
        .navigationTitle(garment.category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    garment.isFavorite.toggle()
                } label: {
                    Image(systemName: garment.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(.pink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditGarmentView(garment: garment)
        }
        .confirmationDialog("Delete this item?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func delete() {
        // Remove the image files after the model, so a failed image delete never
        // blocks removing the garment.
        let reference = ImageAssetReference(
            imageAssetID: garment.imageAssetID,
            thumbnailAssetID: garment.thumbnailAssetID
        )
        modelContext.delete(garment)
        try? modelContext.save()
        let store = container.imageStore
        Task { try? await store.delete(reference) }
        dismiss()
    }
}
