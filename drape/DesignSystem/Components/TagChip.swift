//
//  TagChip.swift
//  drape
//
//  Small pill label used for attributes, occasions and tags.
//

import SwiftUI

/// A compact outlined pill for attributes, occasions and tags — the single tag
/// vocabulary across the app. Optionally shows a leading color swatch (used for
/// `ColorTag`). Non-interactive; styled entirely with adaptive Theme tokens.
struct TagChip: View {
    let text: String
    var swatch: Color?

    init(_ text: String, swatch: Color? = nil) {
        self.text = text
        self.swatch = swatch
    }

    var body: some View {
        HStack(spacing: 6) {
            if let swatch {
                Circle()
                    .fill(swatch)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(Theme.ink.opacity(0.18), lineWidth: 0.5))
            }
            Text(text)
                .font(Theme.body(12.5, weight: .medium))
                .foregroundStyle(Theme.inkSoft)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }
}
