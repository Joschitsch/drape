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
                .scrollContentBackground(.hidden)
                .background(Theme.paper.ignoresSafeArea())
                .presentationDragIndicator(.visible)
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
            ProcessingRitual()
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
            Image("drape.wardrobe")
                .font(.system(size: 52))
                .foregroundStyle(Theme.inkFaint)
            SerifText("Add a piece", size: 22)
            Text("We'll lift it onto a clean canvas so your wardrobe reads like a lookbook.")
                .font(Theme.body(14))
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)

            let hasCamera = UIImagePickerController.isSourceTypeAvailable(.camera)

            if hasCamera {
                Button { showCamera = true } label: {
                    Label("Take Photo", systemImage: "camera").drapePrimaryFill()
                }
                .buttonStyle(.plain)
            }

            // The library picker is primary when there's no camera, otherwise secondary.
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Choose Photo", systemImage: "photo.on.rectangle")
                    .modifier(PhotoButtonFill(primary: !hasCamera))
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

/// Applies the primary or secondary pill fill to a (non-Button) PhotosPicker label.
private struct PhotoButtonFill: ViewModifier {
    let primary: Bool
    func body(content: Content) -> some View {
        if primary { content.drapePrimaryFill() } else { content.drapeSecondaryFill() }
    }
}

// MARK: - Processing ritual

/// The "Quiet Curator" moment: an animated ring + cycling editorial copy shown
/// while the background is removed and the canvas is prepared.
private struct ProcessingRitual: View {
    private let steps = ["Reading the photo", "Lifting the subject", "Preparing the canvas"]
    @State private var step = 0
    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 28) {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Theme.ink, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .frame(width: 44, height: 44)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            VStack(spacing: 10) {
                MonoLabel(steps[step])
                SerifText("Giving it the museum treatment…", size: 21, italic: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 280)
        }
        .padding(40)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = (step + 1) % steps.count
                }
            }
        }
    }
}

#Preview {
    AddGarmentView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
