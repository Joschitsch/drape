//
//  TagEditor.swift
//  drape
//
//  A chip-based editor for a list of free-text tags — existing tags show as
//  removable chips, a field adds new ones on submit. Replaces comma-separated
//  text entry so tags share the app's chip vocabulary.
//

import SwiftUI

struct TagEditor: View {
    @Binding var tags: [String]
    var placeholder: String = "Add a tag"

    @State private var draft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        Button { remove(tag) } label: {
                            HStack(spacing: 5) {
                                Text("#\(tag)")
                                    .font(Theme.body(13, weight: .medium))
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                            }
                            .foregroundStyle(Theme.inkSoft)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .frame(minHeight: 32)
                            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit(add)
                if !draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button("Add", action: add)
                        .font(Theme.body(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private func add() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        draft = ""
        guard !t.isEmpty, !tags.contains(t) else { return }
        tags.append(t)
    }

    private func remove(_ tag: String) {
        tags.removeAll { $0 == tag }
    }
}
