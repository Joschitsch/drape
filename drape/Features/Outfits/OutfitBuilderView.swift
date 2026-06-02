//
//  OutfitBuilderView.swift
//  drape
//
//  Assemble garments into an outfit, one item per slot, and save it.
//

import SwiftUI
import SwiftData

struct OutfitBuilderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model: OutfitBuilderViewModel
    @State private var pickingSlot: OutfitSlot?

    init(editing outfit: Outfit? = nil) {
        _model = State(initialValue: OutfitBuilderViewModel(editing: outfit))
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            Form {
                Section("Details") {
                    TextField("Outfit name", text: $model.name)
                    Picker("Occasion", selection: $model.occasion) {
                        ForEach(Occasion.allCases) { occasion in
                            Label(occasion.displayName, systemImage: occasion.systemImage).tag(occasion)
                        }
                    }
                    TextField("Tags (comma separated)", text: $model.tagsText)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    ForEach(OutfitSlot.builderOrder) { slot in
                        slotRow(slot, model: model)
                    }
                } header: {
                    Text("Items")
                } footer: {
                    Text("Pick footwear and either a dress or a top and bottom.")
                }
            }
            .navigationTitle(model.isEditing ? "Edit Outfit" : "New Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.save(into: modelContext)
                        dismiss()
                    }
                    .disabled(!model.isValid)
                }
            }
            .sheet(item: $pickingSlot) { slot in
                GarmentPickerSheet(slot: slot) { garment in
                    model.select(garment, for: slot)
                }
            }
        }
    }

    @ViewBuilder
    private func slotRow(_ slot: OutfitSlot, model: OutfitBuilderViewModel) -> some View {
        HStack(spacing: 12) {
            if let garment = model.selections[slot] {
                NormalizedImageView(assetID: garment.thumbnailAssetID, category: garment.category)
                    .frame(width: 44, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 2) {
                    Text(slot.displayName)
                    Text("\(garment.primaryColor.displayName) \(garment.category.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    model.clear(slot)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            } else {
                Image(systemName: slot.systemImage)
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.secondary)
                Text("Add \(slot.displayName)")
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { pickingSlot = slot }
    }
}

#Preview {
    OutfitBuilderView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
