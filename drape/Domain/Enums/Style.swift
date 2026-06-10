//
//  Style.swift
//  drape
//
//  Aesthetic styles are free-form strings: six built-ins seed the picker, and
//  users can add their own (saved on `UserProfile.customStyles`) and reuse them
//  everywhere. Stored lowercased on garments and preferences.
//

import Foundation

enum Style {
    /// The styles offered out of the box.
    nonisolated static let builtIns: [String] = ["minimal", "classic", "streetwear", "sporty", "bohemian", "elegant"]

    /// Human-readable label for a raw style string ("old money" → "Old Money").
    nonisolated static func displayName(_ raw: String) -> String {
        raw.split(separator: " ")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    /// Trim + lowercase for storage and de-duplication.
    nonisolated static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Built-ins followed by the user's custom styles, de-duplicated in order.
    nonisolated static func options(custom: [String]) -> [String] {
        var seen = Set<String>()
        return (builtIns + custom).filter { seen.insert($0).inserted }
    }
}
