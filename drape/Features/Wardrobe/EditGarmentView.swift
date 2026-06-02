//
//  EditGarmentView.swift
//  drape
//
//  Edits an existing garment's attributes via the shared attribute form.
//

import SwiftUI
import SwiftData

struct EditGarmentView: View {
    let garment: Garment

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var draft: GarmentDraft

    init(garment: Garment) {
        self.garment = garment
        _draft = State(initialValue: GarmentDraft(from: garment))
    }

    var body: some View {
        NavigationStack {
            Form {
                GarmentAttributeFields(draft: $draft)
            }
            .navigationTitle("Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        draft.apply(to: garment)
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
