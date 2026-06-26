//
//  UndoWearEventTests.swift
//  drapeTests
//
//  The "Undo" on a just-logged wear must actually remove the WearEvent and have
//  it stay gone. Because WearEvent.garments is a many-to-many relationship, a
//  bare context.delete leaves the garment's inverse pointing at the record and
//  SwiftData resurrects it on the next save — so undoWearEvent detaches both
//  sides first. These tests pin that behaviour down.
//

import Foundation
import Testing
import SwiftData
@testable import drape

@MainActor
@Suite("Undo wear event")
struct UndoWearEventTests {

    private func makeGarment(in context: ModelContext) -> Garment {
        let g = Garment(category: .bottom, primaryColor: .ink, name: "Test denim")
        context.insert(g)
        try? context.save()
        return g
    }

    @Test("Undo removes the wear and drops the count back to zero")
    func undoRemovesWear() throws {
        let container = ModelContainer.previewContainer(seeded: false)
        let context = container.mainContext
        let garment = makeGarment(in: context)

        let event = WearEvent(date: .now, outfit: nil, garments: [garment])
        context.insert(event)
        try context.save()
        #expect(garment.wearCount == 1)

        undoWearEvent(event, context: context)

        // In-memory state reflects the removal …
        #expect(garment.wearCount == 0)
        // … and it's actually gone from the store, not just detached.
        let remaining = try context.fetch(FetchDescriptor<WearEvent>())
        #expect(remaining.isEmpty)
    }

    @Test("Undo only removes its own event, leaving prior wears intact")
    func undoLeavesOtherWears() throws {
        let container = ModelContainer.previewContainer(seeded: false)
        let context = container.mainContext
        let garment = makeGarment(in: context)

        let older = WearEvent(date: .now.addingTimeInterval(-86_400), outfit: nil, garments: [garment])
        context.insert(older)
        let latest = WearEvent(date: .now, outfit: nil, garments: [garment])
        context.insert(latest)
        try context.save()
        #expect(garment.wearCount == 2)

        undoWearEvent(latest, context: context)

        #expect(garment.wearCount == 1)
        let remaining = try context.fetch(FetchDescriptor<WearEvent>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.persistentModelID == older.persistentModelID)
    }
}
