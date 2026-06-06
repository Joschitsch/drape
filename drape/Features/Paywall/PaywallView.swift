//
//  PaywallView.swift
//  drape
//
//  Editorial Pro upgrade sheet. Feature list with bordered dividers, serif
//  headline, and a sticky footer CTA. Still backed by MockEntitlementService;
//  real StoreKit 2 purchasing slots in behind EntitlementService in Step 6.
//

import SwiftUI

struct PaywallView: View {
    @Environment(MockEntitlementService.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    private let features: [(title: String, description: String)] = [
        ("Weekly outfit plan",   "Seven looks, planned around your calendar and the forecast."),
        ("Wardrobe analytics",   "Cost-per-wear, most-neglected pieces, and colour balance."),
        ("Unlimited wardrobe",   "Catalogue every garment — no item cap."),
        ("Gap analysis",         "The few pieces that would unlock the most new outfits."),
        ("Advanced AI stylist",  "LLM-powered suggestions beyond the rules engine."),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // ── Hero copy ────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Drape Pro")
                                .font(.caption)
                                .foregroundStyle(Theme.inkFaint)
                                .kerning(0.6)
                                .textCase(.uppercase)
                            Text("Drape already knows your wardrobe.\nLet it know your week.")
                                .font(.title.weight(.semibold))
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Theme.contentPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                        // ── Feature list ─────────────────────────────
                        VStack(spacing: 0) {
                            ForEach(features, id: \.title) { feature in
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(feature.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text(feature.description)
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.inkSoft)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 16)
                                .padding(.horizontal, Theme.contentPadding)

                                Divider().overlay(Theme.line)
                            }
                        }
                    }
                }

                // ── Sticky footer ────────────────────────────────────
                VStack(spacing: 10) {
                    Button {
                        entitlements.tier = .pro
                        dismiss()
                    } label: {
                        Text("Start 7 days free · then 3.99/mo")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.primary)
                            .foregroundStyle(Color(UIColor.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    Text("Cancel anytime · billed monthly · dev build")
                        .font(.caption2)
                        .foregroundStyle(Theme.inkFaint)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .background(Color(UIColor.systemBackground))
                .overlay(alignment: .top) {
                    Divider().overlay(Theme.line)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Theme.surface)
                                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 0.5))
                                .frame(width: 30, height: 30)
                            Image(systemName: "xmark")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(MockEntitlementService())
}
