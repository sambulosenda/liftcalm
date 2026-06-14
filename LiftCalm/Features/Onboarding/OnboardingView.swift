//
//  OnboardingView.swift
//  LiftCalm
//
//  First-run setup. Collects experience, goal, and units into local drafts,
//  then commits them to AppSettings and flips `hasCompletedOnboarding`.
//  Directional, reduce-motion-aware transitions between steps.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Step = .welcome
    /// Drives transition direction (forward = moving deeper into the flow).
    @State private var forward = true

    // Draft selections, committed on finish.
    @State private var experience: ExperienceLevel = .beginner
    @State private var goal: TrainingGoal = .general
    @State private var unit: WeightUnit = .kilograms

    enum Step: Int, CaseIterable {
        case welcome, experience, goal, units, ready

        var isWelcome: Bool { self == .welcome }
        var isLast: Bool { self == .ready }
    }

    var body: some View {
        VStack(spacing: 16) {
            if !step.isWelcome {
                OnboardingProgress(current: step.rawValue - 1, total: Step.allCases.count - 1)
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .transition(.opacity)
            }

            contentArea

            navButtons
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .background(backgroundGradient)
        .animation(stepAnimation, value: step)
        .sensoryFeedback(.selection, trigger: step)
    }

    // MARK: - Content

    private var contentArea: some View {
        GeometryReader { geo in
            ScrollView {
                stepContent
                    .id(step)
                    .transition(stepTransition)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: geo.size.height,
                        alignment: step.isWelcome ? .center : .top
                    )
                    .padding(.horizontal, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: OnboardingWelcomeStep()
        case .experience: OnboardingExperienceStep(selection: $experience)
        case .goal: OnboardingGoalStep(selection: $goal)
        case .units: OnboardingUnitsStep(selection: $unit)
        case .ready: OnboardingReadyStep(experience: experience, goal: goal, unit: unit)
        }
    }

    // MARK: - Navigation

    private var navButtons: some View {
        HStack(spacing: 12) {
            if !step.isWelcome {
                Button("Back") { back() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            Button(primaryTitle) { primaryAction() }
                .buttonStyle(.glassProminentCompat)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .ready: "Start Lifting"
        default: "Continue"
        }
    }

    private func primaryAction() {
        if step.isLast {
            finish()
        } else {
            advance()
        }
    }

    private func advance() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        forward = true
        step = next
    }

    private func back() {
        guard let previous = Step(rawValue: step.rawValue - 1) else { return }
        forward = false
        step = previous
    }

    private func finish() {
        settings.experienceLevel = experience
        settings.goal = goal // also syncs the default rest timer to the goal
        settings.weightUnit = unit
        settings.hasCompletedOnboarding = true
    }

    // MARK: - Styling

    private var stepAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)
    }

    private var stepTransition: AnyTransition {
        if reduceMotion { return .opacity }
        let insertEdge: Edge = forward ? .trailing : .leading
        let removeEdge: Edge = forward ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: insertEdge).combined(with: .opacity),
            removal: .move(edge: removeEdge).combined(with: .opacity)
        )
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(0.10), Theme.calmBlue.opacity(0.04), .clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    OnboardingView()
        .environment(AppSettings())
}
