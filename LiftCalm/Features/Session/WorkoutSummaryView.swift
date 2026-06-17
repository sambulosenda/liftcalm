//
//  WorkoutSummaryView.swift
//  LiftCalm
//
//  Shown after finishing a session. Calm celebration — a gentle seal bounce and
//  haptic, the session's numbers, and any personal records. No confetti storm:
//  encouraging, never overwhelming.
//

import SwiftUI
import SwiftData

/// Payload for the post-workout summary sheet.
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let workout: Workout
    let personalRecords: [PersonalRecord]
}

struct WorkoutSummaryView: View {
    let summary: WorkoutSummary

    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    private var workout: Workout { summary.workout }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.xl) {
                    celebrationHeader
                    statsCard
                    musclesCard
                    if !summary.personalRecords.isEmpty {
                        personalRecordsSection
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(backgroundTint)
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Done") { dismiss() }
                    .buttonStyle(.glassProminentCompat)
                    .controlSize(.extraLarge)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.sm)
            }
        }
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }

    // MARK: - Header

    private var celebrationHeader: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: isPersonalRecord ? "trophy.fill" : "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundStyle(isPersonalRecord ? Theme.caution : Theme.success)
                .symbolEffect(.bounce, value: appeared && !reduceMotion)
                .accessibilityHidden(true)
            Text(headline)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Session saved to your history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Theme.Spacing.sm)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Muscles worked

    /// Front+back activation map for the session. Hidden when nothing
    /// qualifying was logged (e.g. an all-warm-up or empty session).
    @ViewBuilder
    private var musclesCard: some View {
        let sets = workout.muscleSets()
        if !sets.isEmpty {
            MuscleMapCard(setsByGroup: sets, model: settings.bodyModel)
        }
    }

    private var isPersonalRecord: Bool { !summary.personalRecords.isEmpty }

    private var headline: String {
        isPersonalRecord ? "New record — nice!" : "Great work!"
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack {
            stat(Formatting.volume(workout.totalVolume, unit: settings.weightUnit), "Volume")
            Divider().frame(height: 36)
            stat("\(workout.completedSetCount)", "Sets")
            Divider().frame(height: 36)
            stat("\(workout.exerciseCount)", "Exercises")
            if let duration = workout.duration {
                Divider().frame(height: 36)
                stat(Formatting.duration(duration), "Time")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .glassCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - PRs

    private var personalRecordsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Label("Personal Records", systemImage: "trophy.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.caution)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(summary.personalRecords.enumerated()), id: \.element.id) { index, record in
                PersonalRecordRow(record: record, unit: settings.weightUnit)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.4).delay(0.25 + Double(index) * 0.08),
                        value: appeared
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundTint: some View {
        LinearGradient(
            colors: [(isPersonalRecord ? Theme.caution : Theme.success).opacity(0.10), .clear],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }
}

private struct PersonalRecordRow: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: record.isFirstTime ? "sparkles" : "arrow.up.forward.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.caution)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(record.exerciseName)
                    .font(.headline)
                Text(record.isFirstTime ? "First time logged" : "New estimated 1RM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatting.weight(record.estimatedOneRepMaxKilograms, unit: unit))
                .font(.headline.monospacedDigit())
                .foregroundStyle(Theme.caution)
        }
        .padding(Theme.Spacing.lg)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(record.exerciseName), \(record.isFirstTime ? "first time" : "new record"), estimated one rep max \(Formatting.weight(record.estimatedOneRepMaxKilograms, unit: unit))"
        )
    }
}

#Preview {
    let container = PreviewData.container
    let workout = PreviewData.activeWorkout(in: container.mainContext)
    let summary = WorkoutSummary(
        workout: workout,
        personalRecords: [
            PersonalRecord(id: UUID(), exerciseName: "Barbell Bench Press",
                           estimatedOneRepMaxKilograms: 92.5, isFirstTime: false),
            PersonalRecord(id: UUID(), exerciseName: "Bent-Over Row",
                           estimatedOneRepMaxKilograms: 70, isFirstTime: true),
        ]
    )
    return WorkoutSummaryView(summary: summary)
        .modelContainer(container)
        .environment(AppSettings())
}
