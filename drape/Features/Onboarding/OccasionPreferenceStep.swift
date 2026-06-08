//
//  OccasionPreferenceStep.swift
//  drape
//
//  Single onboarding step: pick formality + styles for one occasion.
//

import SwiftUI

struct OccasionPreferenceStep: View {
    let occasion: Occasion
    @Binding var formality: Formality
    @Binding var styles: Set<StyleTag>

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(occasion.iconName)
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.ink)
                    SerifText(occasion.displayName, size: 24)
                }
                Text("How do you like to dress for \(occasion.displayName.lowercased())?")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.inkSoft)
            }

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Formality")
                FlowLayout(spacing: 8) {
                    ForEach(Formality.allCases) { level in
                        DrapeChip(label: level.displayName, active: formality == level) {
                            formality = level
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Style vibes · pick any")
                FlowLayout(spacing: 8) {
                    ForEach(StyleTag.allCases) { tag in
                        let selected = styles.contains(tag)
                        DrapeChip(label: tag.displayName, active: selected) {
                            if selected { styles.remove(tag) } else { styles.insert(tag) }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper.ignoresSafeArea())
    }
}

// MARK: - Simple flow layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0; y += lineHeight + spacing; lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: width, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX; y += lineHeight + spacing; lineHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
