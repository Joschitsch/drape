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
                        VStack(alignment: .leading, spacing: 12) {
                            MonoLabel("Drape Pro")
                            SerifText("Drape already knows your wardrobe. Let it know your week.", size: 30)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, Theme.contentPadding)
                        .padding(.top, 24)
                        .padding(.bottom, 28)

                        // ── Feature list ─────────────────────────────
                        VStack(spacing: 0) {
                            ForEach(features, id: \.title) { feature in
                                VStack(alignment: .leading, spacing: 5) {
                                    SerifText(feature.title, size: 17)
                                    Text(feature.description)
                                        .font(Theme.body(14))
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
                    CTAButton(title: "Start 7 days free · then 3.99/mo") {
                        entitlements.tier = .pro
                        dismiss()
                    }

                    MonoLabel("Cancel anytime · billed monthly · dev build", size: 9.5)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding(.horizontal, Theme.contentPadding)
                .padding(.top, 14)
                .padding(.bottom, 28)
                .background(Theme.paper)
                .overlay(alignment: .top) {
                    Divider().overlay(Theme.line)
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .presentationDragIndicator(.visible)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PaywallView()
        .environment(MockEntitlementService())
}
