//
//  AddGarmentView.swift
//  drape
//
//  Capture/pick a photo, see it normalized, confirm attributes, and save.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddGarmentView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var model = AddGarmentViewModel()
    @State private var pickerItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            content(model: model)
                .navigationTitle("Add Item")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                            .disabled(model.phase != .ready)
                    }
                }
                .fullScreenCover(isPresented: $showCamera) {
                    CameraPicker { data in
                        Task { await model.handlePicked(data: data, container: container) }
                    }
                    .ignoresSafeArea()
                }
                .onChange(of: pickerItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            await model.handlePicked(data: data, container: container)
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private func content(model: AddGarmentViewModel) -> some View {
        switch model.phase {
        case .empty:
            sourcePicker(error: model.errorMessage)
        case .processing:
            ProgressView("Removing background…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready, .saving:
            Form {
                Section {
                    previewImage(model.normalizedImage)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
                GarmentAttributeFields(draft: $model.draft)
            }
            .disabled(model.phase == .saving)
            .overlay {
                if model.phase == .saving {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }

    private func sourcePicker(error: String?) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "tshirt")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Add a clothing item")
                .font(.headline)
            Text("We'll cut out the background so your wardrobe looks consistent.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Choose Photo", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            if let error {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func previewImage(_ image: UIImage?) -> some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 220)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
        }
    }

    private func save() {
        Task {
            if await model.save(into: modelContext, container: container) {
                dismiss()
            }
        }
    }
}

#Preview {
    AddGarmentView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
