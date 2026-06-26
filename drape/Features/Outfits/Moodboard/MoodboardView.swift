//
//  MoodboardView.swift
//  drape
//
//  The editorial outfit Moodboard editor — a layered collage of garment cut-outs
//  on grainy paper. A fixed split: the board is pinned up top, with an
//  always-present wardrobe browser below for tapping pieces in and out. The name
//  is an inline title field and the occasion a native menu picker; a full-screen
//  toggle expands the board to fill the screen. Saving is iOS-Photos-style
//  (overwrite / save as new). Replaces the slot-based OutfitBuilderView.
//

import SwiftUI
import SwiftData

struct MoodboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container

    @State private var model: MoodboardViewModel
    @State private var showingSaveOptions = false
    @State private var saveFailed = false
    @State private var isFullScreen = false

    /// Fraction of the screen the pinned board occupies in split mode.
    private static let boardFraction: CGFloat = 0.58

    init(editing outfit: Outfit? = nil) {
        _model = State(initialValue: MoodboardViewModel(editing: outfit))
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            GeometryReader { geo in
                let boardHeight = isFullScreen ? geo.size.height
                                               : geo.size.height * Self.boardFraction
                let canvasSize = CGSize(width: geo.size.width, height: boardHeight)
                VStack(spacing: 0) {
                    board(canvasSize: canvasSize)
                    if !isFullScreen {
                        WardrobeDrawer(model: model, onTap: handleTap)
                            .frame(height: geo.size.height - boardHeight)
                            .background(
                                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                                    .fill(Theme.surface)
                                    .shadow(color: Theme.shadow, radius: 16, x: 0, y: -6)
                            )
                            .overlay(
                                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                                    .strokeBorder(Theme.line, lineWidth: 0.5)
                            )
                            .transition(.move(edge: .bottom))
                    }
                }
            }
            .background(AppBackground().ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    TextField(model.suggestedName, text: $model.name)
                        .font(Theme.body(16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .frame(maxWidth: 200)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Occasion", selection: $model.occasion) {
                        ForEach(Occasion.allCases) { Text($0.displayName).tag($0) }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(!model.isValid)
                }
            }
            .task { await model.loadAssets(cutout: container.cutout, store: container.imageStore) }
            .confirmationDialog("Save this look", isPresented: $showingSaveOptions,
                                titleVisibility: .visible) {
                Button("Save") { commit(.overwrite) }
                Button("Save as New Look") { commit(.new) }
                Button("Cancel", role: .cancel) {}
            }
            .alert("Couldn’t save this look", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something went wrong saving. Your board is still here — try again.")
            }
        }
    }

    // MARK: - Board

    private func board(canvasSize: CGSize) -> some View {
        MoodboardCanvas(
            placements: model.placements,
            cutouts: model.cutouts,
            fallbacks: model.fallbacks,
            pending: model.pending,
            animated: true,
            size: canvasSize
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
        .overlay(alignment: .topTrailing) { fullScreenToggle }
        .animation(.drapeContent, value: model.selections.mapValues(\.id))
    }

    private var fullScreenToggle: some View {
        Button {
            withAnimation(.snappy(duration: 0.32)) { isFullScreen.toggle() }
        } label: {
            Image(systemName: isFullScreen
                  ? "arrow.down.right.and.arrow.up.left"
                  : "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 34, height: 34)
                .background(Theme.surface.opacity(0.9), in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .padding(12)
        .accessibilityLabel(isFullScreen ? "Exit full screen" : "Full screen")
    }

    // MARK: - Actions

    private func handleTap(_ garment: Garment) {
        withAnimation(.drapeContent) { model.toggle(garment) }
        Task { await model.loadAsset(for: garment, cutout: container.cutout, store: container.imageStore) }
    }

    private func onSave() {
        if model.offersSaveChoice {
            showingSaveOptions = true
        } else {
            commit(.new)
        }
    }

    private func commit(_ mode: MoodboardViewModel.SaveMode) {
        do {
            try model.save(into: modelContext, mode: mode)
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

#Preview {
    MoodboardView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
