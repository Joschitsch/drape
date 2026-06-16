//
//  FoundationModelsStyleArchetypeModel.swift
//  drape
//
//  Archetype inference via Apple's on-device Foundation Models (Apple
//  Intelligence). Guarded three ways so it is never a hard dependency:
//   • `#if canImport(FoundationModels)` — compiles on SDKs without the framework
//   • `@available` — runs only on OS versions that ship it
//   • model `availability` — degrades when the user hasn't enabled Apple
//     Intelligence or the device doesn't support it
//  Any miss falls back to `HeuristicStyleArchetypeModel`, so the snapshot the
//  engine reads is identical regardless of which path produced it.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

struct FoundationModelsStyleArchetypeModel: StyleArchetypeInferring {
    private let fallback: any StyleArchetypeInferring

    init(fallback: any StyleArchetypeInferring = HeuristicStyleArchetypeModel()) {
        self.fallback = fallback
    }

    func inferArchetype(
        descriptor: String?,
        category: GarmentCategory,
        styles: [String]
    ) async -> Archetype? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *),
           let onDevice = await foundationModelArchetype(
               descriptor: descriptor, category: category, styles: styles) {
            return onDevice
        }
        #endif
        return await fallback.inferArchetype(
            descriptor: descriptor, category: category, styles: styles)
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, macOS 26.0, *)
    private func foundationModelArchetype(
        descriptor: String?,
        category: GarmentCategory,
        styles: [String]
    ) async -> Archetype? {
        guard case .available = SystemLanguageModel.default.availability else { return nil }

        let allowed = Archetype.allCases.map(\.rawValue).joined(separator: ", ")
        let item = descriptor ?? category.displayName.lowercased()
        let tags = styles.isEmpty ? "" : " The owner describes it as: \(styles.joined(separator: ", "))."
        let prompt = """
        Classify the style archetype of one clothing item.
        Item: \(item).\(tags)
        Answer with exactly one word from this list and nothing else: \(allowed).
        """

        do {
            let session = LanguageModelSession(
                instructions: "You are a concise fashion stylist. Reply with a single word.")
            let response = try await session.respond(to: prompt)
            let text = response.content.lowercased()
            return Archetype.allCases.first { text.contains($0.rawValue) }
        } catch {
            return nil   // fall through to the heuristic
        }
    }
    #endif
}
