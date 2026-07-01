//
//  MoodboardView.swift
//  drape
//
//  The editorial outfit Moodboard editor — a layered collage of garment cut-outs
//  on grainy paper. The board fills the screen; a draggable wardrobe sheet floats
//  over it (Apple-Maps style) and snaps between three heights — handle-only,
//  middle, and near-top — for tapping pieces in and out. The name is an inline
//  title field and the occasion a HIG pop-up button on the sheet. Saving is
//  iOS-Photos-style (overwrite / save as new). Replaces OutfitBuilderView.
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

    /// Which snap point the draggable wardrobe sheet currently rests at.
    @State private var detent: SheetDetent = .middle
    /// Live finger travel during a drag (+down shrinks the sheet, −up grows it).
    @GestureState private var dragTranslation: CGFloat = 0

    /// The three Apple-Maps-style snap points for the wardrobe sheet, expressed
    /// as a fraction of the full screen height (handle-only `.down` is a fixed
    /// peek, computed separately).
    private enum SheetDetent: CaseIterable {
        case down, middle, up
        var fraction: CGFloat {
            switch self {
            case .down:   return 0      // resolved to a fixed peek height
            case .middle: return 0.5
            case .up:     return 0.92
            }
        }
    }

    /// Visible sheet height at the collapsed `.down` detent — just the grabber.
    private static let collapsedPeek: CGFloat = 30

    /// Task-identity wrapper so cut-out/outline loading only re-runs when the
    /// stable reference size actually changes (e.g. rotation), not on every
    /// value read.
    private struct ReferenceSizeKey: Equatable {
        let size: CGSize
    }

    init(editing outfit: Outfit? = nil) {
        _model = State(initialValue: MoodboardViewModel(editing: outfit))
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            GeometryReader { geo in
                let safeBottom = geo.safeAreaInsets.bottom
                // Full height including the home-indicator zone, so the board
                // bleeds to the screen edge and the sheet can fill it (no peek).
                let fullHeight = geo.size.height + safeBottom
                let base = height(for: detent, fullHeight: fullHeight)
                let live = min(max(base - dragTranslation, Self.collapsedPeek),
                               fullHeight * SheetDetent.up.fraction)
                // The board occupies only the area above the sheet and reflows as
                // the sheet moves, so no piece is ever hidden behind it.
                let boardHeight = max(fullHeight - live, 0)
                // A stable reference size for the outline's thickness math —
                // unlike `boardHeight`, this doesn't change as the sheet drags,
                // so the border doesn't recompute/flicker mid-gesture.
                let referenceSize = CGSize(width: geo.size.width, height: fullHeight)
                ZStack(alignment: .bottom) {
                    board(canvasSize: CGSize(width: geo.size.width, height: boardHeight))
                        .frame(maxHeight: .infinity, alignment: .top)
                    sheet(model: model, height: live, safeBottom: safeBottom,
                          base: base, fullHeight: fullHeight, referenceSize: referenceSize)
                }
                .ignoresSafeArea(.container, edges: .bottom)
                .task(id: ReferenceSizeKey(size: referenceSize)) {
                    await model.loadAssets(cutout: container.cutout, store: container.imageStore,
                                           canvasSize: referenceSize)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave() }
                        .disabled(!model.isValid)
                }
            }
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
            // The paper comes from the screen-filling `AppBackground` behind
            // everything; skipping the canvas's own grain keeps the live resize
            // (as the sheet drags) from re-rendering it every frame.
            showsBackground: false,
            size: canvasSize
        )
        .frame(width: canvasSize.width, height: canvasSize.height)
        .clipped()
        .animation(.drapeContent, value: model.selections.mapValues(\.id))
    }

    // MARK: - Draggable wardrobe sheet

    /// The wardrobe browser as a floating, draggable sheet (Apple-Maps style)
    /// that snaps between three heights. The board stays full behind it.
    private func sheet(model: MoodboardViewModel, height: CGFloat, safeBottom: CGFloat,
                       base: CGFloat, fullHeight: CGFloat, referenceSize: CGSize) -> some View {
        VStack(spacing: 0) {
            grabHandle(base: base, fullHeight: fullHeight)
            occasionSelector
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 2)
                .padding(.bottom, 12)
            WardrobeDrawer(model: model, onTap: { handleTap($0, canvasSize: referenceSize) })
        }
        // Keep the drawer's last row clear of the home indicator while the
        // surface still fills down to the screen edge.
        .padding(.bottom, safeBottom)
        .frame(maxWidth: .infinity)
        .frame(height: height, alignment: .top)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .fill(Theme.surface)
                .shadow(color: Theme.shadow, radius: 16, x: 0, y: -6)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 0.5)
        )
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous)
        )
    }

    /// Centered grabber; also the drag surface that drives the sheet snapping.
    private func grabHandle(base: CGFloat, fullHeight: CGFloat) -> some View {
        Capsule()
            .fill(Theme.line)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .contentShape(Rectangle())
            .gesture(sheetDrag(base: base, fullHeight: fullHeight))
            .accessibilityLabel("Wardrobe sheet")
            .accessibilityHint("Drag to resize the wardrobe")
    }

    /// HIG pop-up button for the look's occasion: a single self-contained control
    /// — icon, value and up/down chevron — reading the current selection.
    private var occasionSelector: some View {
        @Bindable var model = model
        return HStack {
            Menu {
                Picker("Occasion", selection: $model.occasion) {
                    ForEach(Occasion.allCases) { Text($0.displayName).tag($0) }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .medium))
                    Text(model.occasion.displayName)
                        .font(Theme.body(15, weight: .medium))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.inkSoft)
                }
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 38)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 0.5))
            }
            .accessibilityLabel("Occasion: \(model.occasion.displayName)")
            Spacer(minLength: 0)
        }
    }

    /// Visible sheet height for a detent, in the full-height (edge-to-edge) space.
    private func height(for detent: SheetDetent, fullHeight: CGFloat) -> CGFloat {
        detent == .down ? Self.collapsedPeek : fullHeight * detent.fraction
    }

    private func sheetDrag(base: CGFloat, fullHeight: CGFloat) -> some Gesture {
        DragGesture()
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // Snap to the detent whose height is nearest where a flick would
                // carry the sheet — velocity-biased, so a fast drag can cross two
                // detents at once.
                let projected = base - value.predictedEndTranslation.height
                withAnimation(.snappy(duration: 0.32)) {
                    detent = nearestDetent(toHeight: projected, fullHeight: fullHeight)
                }
            }
    }

    /// Pick the snap point whose resting height is closest to `target`.
    private func nearestDetent(toHeight target: CGFloat, fullHeight: CGFloat) -> SheetDetent {
        SheetDetent.allCases.min(by: {
            abs(height(for: $0, fullHeight: fullHeight) - target)
                < abs(height(for: $1, fullHeight: fullHeight) - target)
        }) ?? detent
    }

    // MARK: - Actions

    private func handleTap(_ garment: Garment, canvasSize: CGSize) {
        withAnimation(.drapeContent) { model.toggle(garment) }
        Task {
            await model.loadAsset(for: garment, cutout: container.cutout, store: container.imageStore,
                                  canvasSize: canvasSize)
        }
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
