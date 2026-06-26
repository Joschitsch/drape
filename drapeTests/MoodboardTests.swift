//
//  MoodboardTests.swift
//  drapeTests
//
//  Pins the Moodboard's model invariants (carried from the outfit builder),
//  Photos-style save semantics, and deterministic collage layout.
//

import Foundation
import SwiftData
import Testing
@testable import drape

@MainActor
@Suite("Moodboard")
struct MoodboardTests {

    /// Retained for the test's lifetime so the in-memory store isn't torn down
    /// out from under the context mid-test.
    let container: ModelContainer = .previewContainer(seeded: false)
    private var context: ModelContext { container.mainContext }

    @Test("A dress and separates are mutually exclusive")
    func dressExclusivity() {
        let model = MoodboardViewModel()
        let top = Garment(category: .top, primaryColor: .ink)
        let bottom = Garment(category: .bottom, primaryColor: .ink)
        model.select(top)
        model.select(bottom)
        #expect(model.selectedGarments.count == 2)

        // A dress clears the separates…
        let dress = Garment(category: .dress, primaryColor: .ink)
        model.select(dress)
        #expect(model.selections[.top] == nil)
        #expect(model.selections[.bottom] == nil)
        #expect(model.selectedGarments.map(\.id) == [dress.id])

        // …and choosing a separate again clears the dress.
        model.select(top)
        #expect(model.selections[.fullBody] == nil)
    }

    @Test("Validity, lead piece and auto-name")
    func validityAndLead() {
        let model = MoodboardViewModel()
        #expect(!model.isValid)

        let top = Garment(category: .top, primaryColor: .ink, name: "Linen shirt")
        model.select(top)
        #expect(model.isValid)
        #expect(model.lead?.id == top.id)
        #expect(model.suggestedName == "Linen shirt look")
    }

    @Test("Toggle removes an on-board piece")
    func togglePiece() {
        let model = MoodboardViewModel()
        let shoes = Garment(category: .footwear, primaryColor: .ink)
        model.toggle(shoes)
        #expect(model.isOnBoard(shoes))
        model.toggle(shoes)
        #expect(!model.isOnBoard(shoes))
    }

    @Test("Overwrite updates the same outfit; Save as New inserts a distinct one")
    func saveModes() throws {
        let top = Garment(category: .top, primaryColor: .ink)
        let shoes = Garment(category: .footwear, primaryColor: .ink)
        context.insert(top)
        context.insert(shoes)
        let existing = Outfit(name: "Original")
        context.insert(existing)
        existing.garments = [top]
        try context.save()

        let model = MoodboardViewModel(editing: existing)
        model.select(shoes)

        // Overwrite mutates in place — outfit count unchanged.
        let saved = try model.save(into: context, mode: .overwrite)
        #expect(saved.id == existing.id)
        #expect(Set(existing.garments.map(\.id)) == Set([top.id, shoes.id]))
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 1)

        // Save as new inserts a separate outfit.
        let fresh = try model.save(into: context, mode: .new)
        #expect(fresh.id != existing.id)
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 2)
    }

    @Test("New outfit only ever inserts (no save choice offered)")
    func newOutfitSave() throws {
        let model = MoodboardViewModel()
        #expect(!model.offersSaveChoice)

        let top = Garment(category: .top, primaryColor: .ink)
        context.insert(top)
        model.select(top)

        _ = try model.save(into: context, mode: .new)
        #expect(try context.fetchCount(FetchDescriptor<Outfit>()) == 1)
    }

    @Test("Layout is deterministic and per-garment distinct")
    func layoutDeterminism() {
        let top = Garment(category: .top, primaryColor: .ink)
        let bottom = Garment(category: .bottom, primaryColor: .ink)
        let shoes = Garment(category: .footwear, primaryColor: .ink)
        let garments = [top, bottom, shoes]

        let a = MoodboardLayout.place(garments)
        let b = MoodboardLayout.place(garments)
        #expect(a == b)

        // Distinct placement per garment.
        let centers = Set(a.map { "\($0.center.x),\($0.center.y)" })
        #expect(centers.count == a.count)
    }

    @Test("Adding a piece never moves the existing pieces")
    func layoutIncrementalStability() {
        let top = Garment(category: .top, primaryColor: .ink)
        let bottom = Garment(category: .bottom, primaryColor: .ink)
        let shoes = Garment(category: .footwear, primaryColor: .ink)

        let before = MoodboardLayout.place([top, bottom])
        let after = MoodboardLayout.place([top, bottom, shoes])

        for id in [top.id, bottom.id] {
            #expect(before.first { $0.id == id } == after.first { $0.id == id })
        }
    }

    @Test("Z-order follows clothing anatomy: outerwear behind top, top over bottom")
    func layoutAnatomyZOrder() {
        let outer = Garment(category: .outerwear, primaryColor: .ink)
        let top = Garment(category: .top, primaryColor: .ink)
        let bottom = Garment(category: .bottom, primaryColor: .ink)
        let placed = MoodboardLayout.place([outer, top, bottom])

        func z(_ g: Garment) -> Double { placed.first { $0.id == g.id }!.zIndex }
        #expect(z(outer) < z(top))
        #expect(z(bottom) < z(top))
    }

    @Test("All pieces share the same horizontal centre axis")
    func layoutSharedCenterAxis() {
        let garments = [
            Garment(category: .top, primaryColor: .ink),
            Garment(category: .bottom, primaryColor: .ink),
            Garment(category: .footwear, primaryColor: .ink),
            Garment(category: .accessory, primaryColor: .ink),
        ]
        for placed in MoodboardLayout.place(garments) {
            #expect(placed.center.x == 0.5)
        }
    }

    @Test("Outerwear worn with a top layers behind it and larger")
    func layoutOuterwearOverTop() {
        let top = Garment(category: .top, primaryColor: .ink)
        let outer = Garment(category: .outerwear, primaryColor: .ink)
        let placed = MoodboardLayout.place([top, outer])
        let t = placed.first { $0.id == top.id }!
        let o = placed.first { $0.id == outer.id }!

        #expect(o.zIndex < t.zIndex)                 // behind the top
        #expect(o.widthFraction > t.widthFraction)    // ~15% larger
        #expect(o.center.y > t.center.y)              // offset slightly down
    }
}
