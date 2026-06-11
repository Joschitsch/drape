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
                    VStack(alignment: .leading, spacing: 10) {
                        MonoLabel("Occasion")
                        SingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                                          selection: $model.occasion)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ForEach(OutfitSlot.builderOrder) { slot in
                        slotRow(slot, model: model)
                    }
                } header: {
                    Text("Items")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.paper.ignoresSafeArea())
            .presentationDragIndicator(.visible)
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
        HStack(spacing: 14) {
            if let garment = model.selections[slot] {
                // ── Filled slot ──────────────────────────────────────
                NormalizedImageView(assetID: garment.thumbnailAssetID)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: Theme.shadow, radius: 4, x: 0, y: 2)
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(slot.displayName, size: 9)
                    Text(garment.displayName)
                        .font(Theme.body(15, weight: .medium)).foregroundStyle(Theme.ink).lineLimit(1)
                }
                Spacer()
                Button {
                    model.clear(slot)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.inkFaint)
                }
                .buttonStyle(.borderless)
            } else {
                // ── Empty slot ───────────────────────────────────────
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    Image(slot.iconName)
                        .font(.body)
                        .foregroundStyle(Theme.inkFaint.opacity(0.6))
                }
                .frame(width: 46, height: 56)
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(slot.displayName, size: 9)
                    Text("Add a piece")
                        .font(Theme.body(15)).foregroundStyle(Theme.inkSoft)
                }
                Spacer()
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.inkFaint)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .onTapGesture { pickingSlot = slot }
    }
}

#Preview {
    OutfitBuilderView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
