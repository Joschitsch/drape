//
//  WardrobeAnalyticsView.swift
//  drape
//
//  Pro-gated analytics: cost-per-wear and rarely-used items.
//  Gated behind ProFeature.wardrobeAnalytics via EntitlementService.
//

import SwiftUI
import SwiftData

struct WardrobeAnalyticsView: View {
    @Query(filter: #Predicate<Garment> { !$0.isArchived },
           sort: \Garment.createdAt)
    private var garments: [Garment]

    private var costPerWearItems: [CostPerWear] {
        garments
            .compactMap { g -> CostPerWear? in
                guard let price = g.purchasePrice, price > 0, g.wearCount > 0 else { return nil }
                return CostPerWear(garment: g, value: price / Decimal(g.wearCount))
            }
            .sorted { $0.value > $1.value }
    }

    // Garments not worn in the past 90 days (and added > 30 days ago so new items aren't flagged).
    private var rarelyUsed: [Garment] {
        let cutoff = Date.now.addingTimeInterval(-90 * 86_400)
        let addedCutoff = Date.now.addingTimeInterval(-30 * 86_400)
        return garments.filter { g in
            g.createdAt < addedCutoff &&
            (g.wearEvents.isEmpty || (g.wearEvents.map(\.date).max() ?? .distantPast) < cutoff)
        }
        .sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            if costPerWearItems.isEmpty && rarelyUsed.isEmpty {
                ContentUnavailableView(
                    "No data yet",
                    image: "drape.analytics",
                    description: Text("Log some wears and add purchase prices to see analytics.")
                )
                .padding(.top, 60)
            } else {
                VStack(spacing: 20) {
                    if !costPerWearItems.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            MonoLabel("Cost per wear")
                                .padding(.horizontal, Theme.contentPadding)
                            VStack(spacing: 0) {
                                ForEach(Array(costPerWearItems.enumerated()), id: \.element.id) { idx, item in
                                    HStack {
                                        NormalizedImageView(assetID: item.garment.thumbnailAssetID)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 3) {
                                            SerifText(item.garment.displayName, size: 16).lineLimit(1)
                                            MonoLabel("\(item.garment.wearCount) wear\(item.garment.wearCount == 1 ? "" : "s")", size: 9)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(item.value, format: .currency(code: Locale.current.currency?.identifier ?? "USD"))
                                                .font(Theme.mono(14, weight: .medium))
                                                .foregroundStyle(Theme.ink)
                                            if item.value < 5 {
                                                MonoLabel("GREAT BUY", size: 9)
                                            } else if item.value >= 20 {
                                                MonoLabel("COSTLY", size: 9)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    if idx < costPerWearItems.count - 1 {
                                        Theme.line.frame(height: 0.5).padding(.leading, 76)
                                    }
                                }
                            }
                            .drapeCard(radius: 14)
                            .padding(.horizontal, Theme.contentPadding)
                        }
                    }

                    if !rarelyUsed.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                MonoLabel("Rarely used")
                                    .padding(.horizontal, Theme.contentPadding)
                                Text("Added over 30 days ago with no recent wears.")
                                    .font(Theme.body(12))
                                    .foregroundStyle(Theme.inkSoft)
                                    .padding(.horizontal, Theme.contentPadding)
                            }
                            VStack(spacing: 0) {
                                ForEach(Array(rarelyUsed.enumerated()), id: \.element.id) { idx, garment in
                                    HStack {
                                        NormalizedImageView(assetID: garment.thumbnailAssetID)
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                        VStack(alignment: .leading, spacing: 3) {
                                            SerifText(garment.displayName, size: 16).lineLimit(1)
                                            MonoLabel(garment.wearCount == 0 ? "Never worn" : "Last worn 90+ days ago", size: 9)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    if idx < rarelyUsed.count - 1 {
                                        Theme.line.frame(height: 0.5).padding(.leading, 76)
                                    }
                                }
                            }
                            .drapeCard(radius: 14)
                            .padding(.horizontal, Theme.contentPadding)
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .background(Theme.paper.ignoresSafeArea())
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct CostPerWear: Identifiable {
    let garment: Garment
    let value: Decimal
    var id: UUID { garment.id }
}

#Preview {
    NavigationStack {
        WardrobeAnalyticsView()
            .modelContainer(.previewContainer())
    }
}
