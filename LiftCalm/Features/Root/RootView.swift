//
//  RootView.swift
//  LiftCalm
//
//  Top-level tab scaffold. While a session is active, a persistent bottom
//  accessory ("Now training") lets the user jump back into it from any tab —
//  one of the app's fast-access promises.
//

import SwiftUI

struct RootView: View {
    @Environment(SessionController.self) private var session
    @State private var selectedTab: AppTab = .today
    @State private var showingActiveWorkout = false
    /// Presented after the active-workout sheet finishes dismissing, so the two
    /// sheets never contend for presentation in the same frame.
    @State private var pendingSummary: WorkoutSummary?
    /// Non-nil while the Plus paywall is shown; the value is the gate that opened it.
    @State private var paywallContext: PaywallContext?

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "figure.strengthtraining.traditional", value: AppTab.today) {
                TodayView(showingActiveWorkout: $showingActiveWorkout)
            }
            Tab("History", systemImage: "clock.arrow.circlepath", value: AppTab.history) {
                HistoryView()
            }
            Tab("Progress", systemImage: "chart.xyaxis.line", value: AppTab.progress) {
                ProgressDashboardView()
            }
            Tab("Library", systemImage: "books.vertical", value: AppTab.library) {
                LibraryView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        // Gate the accessory *modifier*, not its content: returning an empty view
        // from inside `tabViewBottomAccessory` still draws the persistent (empty)
        // glass bar. The explicit `selection` binding above keeps the toggle's
        // identity change from snapping the user back to the first tab.
        .bottomAccessory(session.isWorkoutActive) {
            NowTrainingAccessory { showingActiveWorkout = true }
        }
        .sheet(isPresented: $showingActiveWorkout, onDismiss: {
            // Surface the celebratory summary only once the active sheet is gone.
            pendingSummary = session.lastFinishedSummary
        }) {
            ActiveWorkoutView()
        }
        .sheet(item: $pendingSummary, onDismiss: { session.lastFinishedSummary = nil }) { summary in
            WorkoutSummaryView(summary: summary)
        }
        .sheet(item: $paywallContext) { context in
            PaywallView(context: context)
        }
        // Single app-level entry point for the paywall: any gated view calls
        // `presentPaywall(.someContext)` and this hosts the sheet above the tabs.
        .environment(\.presentPaywall, { paywallContext = $0 })
    }
}

/// Compact control above the tab bar that resumes the in-progress session.
private struct NowTrainingAccessory: View {
    @Environment(SessionController.self) private var session
    let resume: () -> Void

    var body: some View {
        Button(action: resume) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Now training")
                        .font(.subheadline.weight(.semibold))
                    if let workout = session.activeWorkout {
                        Text(liveSummary(workout))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if session.isResting {
                    RestPill()
                } else {
                    Image(systemName: "chevron.up")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Resume current workout")
    }

    private func liveSummary(_ workout: Workout) -> String {
        let exercises = workout.exerciseCount
        let sets = workout.completedSetCount
        return "\(exercises) exercise\(exercises == 1 ? "" : "s") · \(sets) set\(sets == 1 ? "" : "s") done"
    }
}

/// Live rest countdown shown inside the accessory.
private struct RestPill: View {
    @Environment(SessionController.self) private var session

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Label(
                Formatting.clock(session.restSecondsRemaining(asOf: context.date)),
                systemImage: "timer"
            )
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(Theme.calmBlue)
            .labelStyle(.titleAndIcon)
        }
    }
}

private enum AppTab: Hashable {
    case today, history, progress, library, settings
}

private extension View {
    /// Applies `tabViewBottomAccessory` only when `visible`. Gating the modifier
    /// (rather than returning empty content from inside it) is what actually
    /// removes the bar — an empty accessory builder still reserves and draws the
    /// persistent glass slot.
    @ViewBuilder
    func bottomAccessory<Accessory: View>(
        _ visible: Bool,
        @ViewBuilder content: () -> Accessory
    ) -> some View {
        if visible {
            tabViewBottomAccessory(content: content)
        } else {
            self
        }
    }
}
