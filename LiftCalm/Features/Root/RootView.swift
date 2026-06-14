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
    @State private var showingActiveWorkout = false
    /// Presented after the active-workout sheet finishes dismissing, so the two
    /// sheets never contend for presentation in the same frame.
    @State private var pendingSummary: WorkoutSummary?

    var body: some View {
        TabView {
            Tab("Today", systemImage: "figure.strengthtraining.traditional") {
                TodayView(showingActiveWorkout: $showingActiveWorkout)
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                HistoryView()
            }
            Tab("Library", systemImage: "books.vertical") {
                LibraryView()
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tabViewBottomAccessory {
            if session.isWorkoutActive {
                NowTrainingAccessory { showingActiveWorkout = true }
            }
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
    }
}

/// Compact control above the tab bar that resumes the in-progress session.
private struct NowTrainingAccessory: View {
    @Environment(SessionController.self) private var session
    let resume: () -> Void

    var body: some View {
        Button(action: resume) {
            HStack(spacing: 10) {
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
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
            .padding(.horizontal, 12)
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
