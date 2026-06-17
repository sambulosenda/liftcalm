//
//  PaywallView.swift
//  LiftCalm
//
//  The one-time "LiftCalm Plus" unlock. Calm by design — no countdowns, no dark
//  patterns: a clear benefit list, an honest one-time price, and a visible close
//  button. The headline adapts to whichever gate opened it (PaywallContext).
//

import SwiftUI
import StoreKit

extension EnvironmentValues {
    /// Presents the Plus paywall for the gate that triggered it. Injected by
    /// `RootView`; defaults to a no-op so previews and detached views are safe.
    @Entry var presentPaywall: (PaywallContext) -> Void = { _ in }
}

struct PaywallView: View {
    let context: PaywallContext

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// What Plus unlocks today.
    private let benefits: [Benefit] = [
        Benefit("infinity", "Unlimited routines", "Save as many custom routines as your training needs."),
        Benefit("chart.xyaxis.line", "Progress charts", "Estimated 1RM and volume trends for every exercise."),
        Benefit("heart.text.square", "Full recovery breakdown", "See every factor behind your readiness score."),
        Benefit("square.grid.2x2", "Home Screen widgets", "Readiness and quick-start at a glance."),
    ]

    private var isBusy: Bool { store.purchaseState == .purchasing }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    benefitsCard
                    reassurance
                }
                .padding(Theme.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .safeAreaInset(edge: .bottom) { purchaseBar }
            .navigationTitle("LiftCalm Plus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
            .background(backgroundTint)
        }
        // Dismiss as soon as the unlock lands (purchase, restore, or Ask-to-Buy
        // approval arriving via the updates listener).
        .onChange(of: store.isPlus) { _, unlocked in
            if unlocked { dismiss() }
        }
        .alert("Purchase failed", isPresented: failedBinding) {
            Button("OK") { store.clearError() }
        } message: {
            if case .failed(let message) = store.purchaseState { Text(message) }
        }
        .task { if store.plusProduct == nil { await store.loadProduct() } }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(context.headline)
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(context.subheadline)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.top, Theme.Spacing.xs)
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(benefits.enumerated()), id: \.element.id) { index, benefit in
                if index > 0 { Divider().padding(.leading, 56) }
                BenefitRow(benefit: benefit, tint: Theme.accent)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .glassCard()
    }

    private var reassurance: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label(
                "Pay once, keep it forever — no subscription. Many trackers cost about that every month.",
                systemImage: "infinity"
            )
            Label(
                "Logging, your full history, and data export are always free.",
                systemImage: "checkmark.shield"
            )
            Label(
                "No account needed — your data stays on your device.",
                systemImage: "lock.shield"
            )
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Purchase bar

    private var purchaseBar: some View {
        VStack(spacing: Theme.Spacing.md) {
            Button(action: { Task { await store.purchase() } }) {
                Group {
                    if isBusy {
                        ProgressView().tint(.white)
                    } else {
                        Text(buyTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminentCompat)
            .controlSize(.extraLarge)
            .disabled(isBusy || store.plusProduct == nil)
            .accessibilityLabel(buyAccessibilityLabel)

            Button("Restore Purchases") { Task { await store.restore() } }
                .font(.subheadline)
                .disabled(isBusy)

            Text("One-time purchase · no subscription, ever")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.sm)
        .background(.bar)
    }

    private var buyTitle: String {
        if let price = store.plusProduct?.displayPrice {
            "Unlock Plus · \(price)"
        } else {
            "Unlock Plus"
        }
    }

    private var buyAccessibilityLabel: String {
        if let price = store.plusProduct?.displayPrice {
            "Unlock LiftCalm Plus for \(price), one-time purchase"
        } else {
            "Unlock LiftCalm Plus"
        }
    }

    private var failedBinding: Binding<Bool> {
        Binding(
            get: { if case .failed = store.purchaseState { true } else { false } },
            set: { if !$0 { store.clearError() } }
        )
    }

    private var backgroundTint: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(0.08), .clear],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }
}

// MARK: - Benefit row

private struct Benefit: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String

    init(_ symbol: String, _ title: String, _ detail: String) {
        self.symbol = symbol
        self.title = title
        self.detail = detail
    }
}

private struct BenefitRow: View {
    let benefit: Benefit
    let tint: Color
    var muted: Bool = false

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: benefit.symbol)
                .font(.title3)
                .foregroundStyle(muted ? AnyShapeStyle(.secondary) : AnyShapeStyle(tint))
                .frame(width: 42, height: 42)
                .background(tint.opacity(muted ? 0.06 : 0.12), in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(benefit.title)
                    .font(.headline)
                Text(benefit.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Routines") {
    PaywallView(context: .routines)
        .environment(StoreManager())
}

#Preview("Readiness") {
    PaywallView(context: .readiness)
        .environment(StoreManager())
}
