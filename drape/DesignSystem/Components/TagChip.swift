//
//  TagChip.swift
//  drape
//
//  Small pill label used for attributes, occasions and tags.
//

import SwiftUI

/// A compact rounded label. Optionally shows a leading color swatch (used for
/// `ColorTag`).
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
                    .overlay(Circle().strokeBorder(.separator, lineWidth: 0.5))
            }
            Text(text)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: Capsule())
    }
}
