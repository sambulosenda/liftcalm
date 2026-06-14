//
//  TodayView.swift
//  LiftCalm
//
//  The home base: start a session fast (empty or from a template) and glance at
//  recent activity. Designed around a single, obvious primary action.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(SessionController.self) private var session
    @Environment(\.modelContext) private var context
    @Binding var showingActiveWorkout: Bool

    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]
    @Query(
        filter: #Predicate<Workout> { $0.endedAt != nil },
        sort: \Workout.startedAt, order: .reverse
    )
    private var finishedWorkouts: [Workout]

    private var recentWorkouts: [Workout] { Array(finishedWorkouts.prefix(3)) }

    /// Training-load-based readiness (no HealthKit yet; engine accepts optional
    /// sleep/HRV/RHR signals when those are wired in later).
    private var readiness: ReadinessScore {
        ReadinessEngine.compute(load: TrainingLoad.from(workouts: finishedWorkouts, now: Date()))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ReadinessCard(score: readiness)
                    primaryAction
                    templatesSection
                    recentSection
                }
                .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .navigationTitle("Today")
            .background(backgroundTint)
        }
    }

    // MARK: - Primary action

    private var primaryAction: some View {
        VStack(spacing: 12) {
            Button {
                startEmpty()
            } label: {
                Label("Start Workout", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminentCompat)
            .controlSize(.extraLarge)
            .accessibilityHint("Begins a new empty session")

            if session.isWorkoutActive {
                Button("Resume current workout") { showingActiveWorkout = true }
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Templates

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Quick Start", subtitle: "Begin from a routine")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(templates) { template in
                        TemplateCard(template: template) { start(from: template) }
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollClipDisabled()
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Recent", subtitle: nil)
            if recentWorkouts.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "figure.cooldown",
                    description: Text("Your finished sessions will appear here.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                ForEach(recentWorkouts) { workout in
                    NavigationLink {
                        WorkoutDetailView(workout: workout)
                    } label: {
                        WorkoutRow(workout: workout)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var backgroundTint: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(0.06), .clear],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }

    // MARK: - Actions

    private func startEmpty() {
        guard !session.isWorkoutActive else { showingActiveWorkout = true; return }
        session.startEmptyWorkout()
        showingActiveWorkout = true
    }

    private func start(from template: WorkoutTemplate) {
        guard !session.isWorkoutActive else { showingActiveWorkout = true; return }
        session.startWorkout(from: template)
        showingActiveWorkout = true
    }
}

// MARK: - Subviews

private struct TemplateCard: View {
    let template: WorkoutTemplate
    let action: () -> Void

    // Scale the card with Dynamic Type so titles/summaries don't truncate at
    // large accessibility sizes.
    @ScaledMetric private var cardWidth = 170
    @ScaledMetric private var cardHeight = 130

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(2)
                Text(template.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Label("\(template.items.count) exercises", systemImage: "list.bullet")
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(Theme.accent)
            }
            .padding(16)
            .frame(width: cardWidth, height: cardHeight, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name) template, \(template.items.count) exercises")
        .accessibilityHint("Starts a workout from this routine")
    }
}

#Preview {
    @Previewable @State var showing = false
    return TodayView(showingActiveWorkout: $showing)
        .modelContainer(PreviewData.container)
        .environment(AppSettings())
        .environment(SessionController())
}
