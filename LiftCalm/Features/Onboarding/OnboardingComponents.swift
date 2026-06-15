//
//  OnboardingComponents.swift
//  LiftCalm
//
//  Reusable pieces for the onboarding flow: a consistent step scaffold, the
//  selectable choice card, and the step progress indicator.
//

import SwiftUI

/// Title + subtitle header and a content slot, shared by every step so spacing
/// and typography stay consistent.
struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A tappable option with optional icon, title, subtitle, and selection state.
struct OnboardingChoiceCard: View {
    let title: String
    var subtitle: String?
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var iconSize = 26

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.lg) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: iconSize))
                        .foregroundStyle(isSelected ? Theme.accent : .secondary)
                        .frame(width: iconSize + 12)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        isSelected ? Theme.accent : Color.clear,
                        lineWidth: 2
                    )
            }
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// Slim segmented progress bar for the setup steps (welcome excluded).
struct OnboardingProgress: View {
    /// 0-based index of the current step among the counted steps.
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(index <= current ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary))
                    .frame(height: 5)
            }
        }
        .animation(.smooth, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
    }
}
