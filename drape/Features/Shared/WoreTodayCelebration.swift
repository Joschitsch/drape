//
//  WoreTodayCelebration.swift
//  drape
//
//  The "Wore today" moment — a full-screen overlay that acknowledges the wear
//  log with warmth. Auto-dismisses after 3.2 seconds; tap anywhere to dismiss.
//

import SwiftUI

struct WoreTodayCelebration: View {
    let garment: Garment
    let isFirstWear: Bool
    let onDismiss: () -> Void

    @State private var canvasVisible = false
    @State private var ringScale: CGFloat = 0.7
    @State private var ringOpacity: Double = 1
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        ZStack {
            // ── Blurred backdrop ─────────────────────────────────────
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                // ── Canvas + ring + checkmark ────────────────────────
                ZStack(alignment: .bottomTrailing) {
                    // Expanding ring
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                        .frame(width: 170, height: 192)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Garment canvas
                    GarmentCanvasView(
                        category: garment.category,
                        color: garment.primaryColor.color
                    )
                    .frame(width: 150, height: 172)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 12)
                    .scaleEffect(canvasVisible ? 1 : 0.88)
                    .opacity(canvasVisible ? 1 : 0)

                    // Checkmark badge
                    ZStack {
                        Circle()
                            .fill(.primary)
                            .frame(width: 42, height: 42)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color(UIColor.systemBackground))
                    }
                    .scaleEffect(checkmarkScale)
                    .offset(x: 10, y: 10)
                }

                // ── Copy ─────────────────────────────────────────────
                VStack(spacing: 8) {
                    Text(isFirstWear ? "First wear logged" : "Noted for today")
                        .font(.caption)
                        .foregroundStyle(Theme.inkFaint)
                        .kerning(0.6)
                        .textCase(.uppercase)

                    Text(isFirstWear
                         ? "The \(garment.displayName.lowercased()) is officially in your life."
                         : "Good choice. The \(garment.displayName.lowercased()) is back in rotation.")
                        .font(.title3.italic())
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 32)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .onAppear { animate() }
    }

    private func animate() {
        // Canvas rises in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
            canvasVisible = true
        }
        // Ring expands and fades
        withAnimation(.easeOut(duration: 1.4).delay(0.15)) {
            ringScale = 1.2
            ringOpacity = 0
        }
        // Checkmark pops in
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55).delay(0.5)) {
            checkmarkScale = 1
        }
        // Auto-dismiss
        Task {
            try? await Task.sleep(for: .seconds(3.2))
            onDismiss()
        }
    }
}

#Preview {
    WoreTodayCelebration(
        garment: PreviewData.sampleGarments().first!,
        isFirstWear: true,
        onDismiss: {}
    )
}
