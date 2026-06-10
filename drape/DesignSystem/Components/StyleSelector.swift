//
//  StyleSelector.swift
//  drape
//
//  Multi-select style picker: built-in + the user's custom styles as chips,
//  plus an "add your own" field. Adding a style selects it and registers it
//  (via `onAdd`) so it's reusable everywhere.
//

import SwiftUI

struct StyleSelector: View {
    @Binding var selection: Set<String>
    /// The user's saved custom styles (shown as options alongside the built-ins).
    var customStyles: [String] = []
    /// Called when a brand-new style is added, so the host can persist it.
    var onAdd: (String) -> Void = { _ in }

    @State private var draft = ""

    private var options: [String] {
        // Built-ins + customs + anything already selected (so off-list values still show).
        Style.options(custom: customStyles + selection.sorted())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            FlowLayout(spacing: 8) {
                ForEach(options, id: \.self) { style in
                    let isOn = selection.contains(style)
                    DrapeChip(label: Style.displayName(style), active: isOn) {
                        if isOn { selection.remove(style) } else { selection.insert(style) }
                    }
                }
            }
            HStack {
                TextField("Add your own…", text: $draft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(Theme.body(15))
                    .onSubmit(add)
                if !Style.normalize(draft).isEmpty {
                    Button("Add", action: add)
                        .font(Theme.body(15, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
    }

    private func add() {
        let s = Style.normalize(draft)
        draft = ""
        guard !s.isEmpty else { return }
        selection.insert(s)
        if !Style.builtIns.contains(s), !customStyles.contains(s) {
            onAdd(s)
        }
    }
}
