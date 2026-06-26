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
    @State private var saveFailed = false

    init(editing outfit: Outfit? = nil) {
        _model = State(initialValue: OutfitBuilderViewModel(editing: outfit))
    }

    var body: some View {
        @Bindable var model = model
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // ── Details card ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 0) {
                        // Placeholder previews the auto-name (updates as pieces
                        // are added), so the user can save without typing.
                        TextField(model.suggestedName, text: $model.name)
                            .font(Theme.body(15))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                        Theme.line.frame(height: 0.5)
                        VStack(alignment: .leading, spacing: 10) {
                            MonoLabel("Occasion")
                            SingleChoiceChips(items: Occasion.allCases, title: \.displayName,
                                              selection: $model.occasion)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                    }
                    .drapeCard(radius: 14)
                    .padding(.horizontal, Theme.contentPadding)

                    // ── Items card ────────────────────────────────────────
                    let slots = visibleSlots(model)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(slots.enumerated()), id: \.element.id) { idx, slot in
                            slotButton(slot, model: model)
                            if slot == .fullBody, model.selections[.fullBody] != nil {
                                // The dress fills the top+bottom roles; say so.
                                MonoLabel("Covers your top & bottom", size: 9)
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 10)
                            }
                            if idx < slots.count - 1 {
                                separator(after: slot, in: slots)
                            }
                        }
                    }
                    .drapeCard(radius: 14)
                    .padding(.horizontal, Theme.contentPadding)

                    if !model.isValid {
                        MonoLabel("Add at least one piece to save", size: 9)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 2)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .background(AppBackground().ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .navigationTitle(model.isEditing ? "Edit Outfit" : "New Outfit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do {
                            try model.save(into: modelContext)
                            dismiss()
                        } catch {
                            saveFailed = true
                        }
                    }
                    .disabled(!model.isValid)
                }
            }
            .sheet(item: $pickingSlot) { slot in
                GarmentPickerSheet(slot: slot) { garment in
                    model.select(garment, for: slot)
                }
            }
            .alert("Couldn’t save this outfit", isPresented: $saveFailed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Something went wrong saving. Your selections are still here — try again.")
            }
        }
    }

    /// Slots to show given the current selection: a dress and separates are
    /// mutually exclusive, so we only ever offer one path at a time.
    private func visibleSlots(_ model: OutfitBuilderViewModel) -> [OutfitSlot] {
        let hasDress = model.selections[.fullBody] != nil
        let hasSeparate = model.selections[.top] != nil || model.selections[.bottom] != nil
        return OutfitSlot.builderOrder.filter { slot in
            switch slot {
            case .top, .bottom: return !hasDress
            case .fullBody:     return !hasSeparate
            default:            return true
            }
        }
    }

    /// The separator between two visible rows. Between the Dress and Top rows
    /// (only adjacent when neither path is chosen yet) it reads "or" to signal a
    /// choice; everywhere else it's the standard inset hairline.
    @ViewBuilder
    private func separator(after slot: OutfitSlot, in slots: [OutfitSlot]) -> some View {
        if slot == .fullBody, slots.contains(.top) {
            HStack(spacing: 10) {
                Theme.line.frame(height: 0.5)
                MonoLabel("or", size: 9)
                Theme.line.frame(height: 0.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        } else {
            Theme.line.frame(height: 0.5).padding(.leading, 80)
        }
    }

    /// A tappable slot row. Exposed to VoiceOver as a single button element with
    /// a default "choose" action plus a "Remove" action when filled, so the row
    /// is actionable without breaking the inner clear button for sighted users.
    @ViewBuilder
    private func slotButton(_ slot: OutfitSlot, model: OutfitBuilderViewModel) -> some View {
        let base = slotRow(slot, model: model)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { pickingSlot = slot }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(
                model.selections[slot].map { "\(slot.displayName): \($0.displayName)" }
                    ?? "Add \(slot.displayName.lowercased())"
            )
            .accessibilityAction { pickingSlot = slot }

        if model.selections[slot] != nil {
            base.accessibilityAction(named: Text("Remove")) { model.clear(slot) }
        } else {
            base.accessibilityHint(Text("Choose a \(slot.displayName.lowercased())"))
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
    }
}

#Preview {
    OutfitBuilderView()
        .modelContainer(.previewContainer())
        .environment(AppContainer.preview())
}
