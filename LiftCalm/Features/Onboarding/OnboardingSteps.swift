//
//  OnboardingSteps.swift
//  LiftCalm
//
//  Individual step screens. Each is a small, self-contained view bound to a
//  draft selection so the flow can commit everything at the end.
//

import SwiftUI

// MARK: - Welcome

struct OnboardingWelcomeStep: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 132, height: 132)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 60, weight: .regular))
                    .foregroundStyle(Theme.accent)
                    .symbolEffect(.breathe, options: .repeating, isActive: animate && !reduceMotion)
            }
            .glassCard(cornerRadius: 66)
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.md) {
                Text("LiftCalm")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("Fast. Focused. Fair.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.accent)
                Text("A calm, private companion for your strength training. No account, no noise — just your progress.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.sm)
                    .padding(.top, Theme.Spacing.xs)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear { animate = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("LiftCalm. Fast, focused, fair. A calm, private companion for your strength training.")
    }
}

// MARK: - Experience

struct OnboardingExperienceStep: View {
    @Binding var selection: ExperienceLevel

    private func subtitle(for level: ExperienceLevel) -> String {
        switch level {
        case .beginner: "New to lifting or returning after a break"
        case .intermediate: "Comfortable with the main lifts"
        case .advanced: "Years of consistent training"
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Your experience",
            subtitle: "We'll tailor suggestions to your level."
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(ExperienceLevel.allCases) { level in
                    OnboardingChoiceCard(
                        title: level.displayName,
                        subtitle: subtitle(for: level),
                        isSelected: selection == level
                    ) {
                        selection = level
                    }
                }
            }
        }
    }
}

// MARK: - Goal

struct OnboardingGoalStep: View {
    @Binding var selection: TrainingGoal

    private func detail(for goal: TrainingGoal) -> String {
        switch goal {
        case .strength: "Heavy, lower reps · longer rest"
        case .hypertrophy: "Moderate reps · build muscle"
        case .endurance: "Higher reps · shorter rest"
        case .general: "Stay strong and healthy"
        }
    }

    private func symbol(for goal: TrainingGoal) -> String {
        switch goal {
        case .strength: "scalemass"
        case .hypertrophy: "figure.arms.open"
        case .endurance: "wind"
        case .general: "heart"
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Main goal",
            subtitle: "This sets your default rest timer — change it anytime."
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(TrainingGoal.allCases) { goal in
                    OnboardingChoiceCard(
                        title: goal.displayName,
                        subtitle: detail(for: goal),
                        systemImage: symbol(for: goal),
                        isSelected: selection == goal
                    ) {
                        selection = goal
                    }
                }
            }
        }
    }
}

// MARK: - Units

struct OnboardingUnitsStep: View {
    @Binding var selection: WeightUnit

    var body: some View {
        OnboardingStepScaffold(
            title: "Preferred units",
            subtitle: "How would you like to enter weights?"
        ) {
            VStack(spacing: Theme.Spacing.md) {
                ForEach(WeightUnit.allCases) { unit in
                    OnboardingChoiceCard(
                        title: unit.displayName,
                        systemImage: unit == .kilograms ? "scalemass.fill" : "scalemass",
                        isSelected: selection == unit
                    ) {
                        selection = unit
                    }
                }
            }
        }
    }
}

// MARK: - Ready

struct OnboardingReadyStep: View {
    let experience: ExperienceLevel
    let goal: TrainingGoal
    let unit: WeightUnit

    var body: some View {
        OnboardingStepScaffold(
            title: "You're all set",
            subtitle: "Here's your starting point."
        ) {
            VStack(spacing: Theme.Spacing.lg) {
                summaryCard
                templatesCard
                disclaimer
            }
        }
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            summaryRow("Experience", experience.displayName, "figure.run")
            Divider().padding(.leading, 52)
            summaryRow("Goal", goal.displayName, "target")
            Divider().padding(.leading, 52)
            summaryRow("Units", unit.abbreviation.uppercased(), "scalemass")
        }
        .padding(.vertical, Theme.Spacing.xs)
        .glassCard()
    }

    private func summaryRow(_ label: String, _ value: String, _ symbol: String) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(label)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var templatesCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(Theme.calmBlue)
                .accessibilityHidden(true)
            Text("We've added **Push**, **Pull**, **Legs**, and **Full Body** routines to get you going.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var disclaimer: some View {
        Label {
            Text("LiftCalm is not medical advice. Consult a professional before starting any program.")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.top, Theme.Spacing.xs)
    }
}
