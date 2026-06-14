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
                VStack(spacing: 24) {
                    celebrationHeader
                    statsCard
                    if !summary.personalRecords.isEmpty {
                        personalRecordsSection
                    }
                }
                .padding(20)
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }
        }
        .onAppear { appeared = true }
        .sensoryFeedback(.success, trigger: appeared)
    }

    // MARK: - Header

    private var celebrationHeader: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 76))
                .foregroundStyle(Theme.success)
                .symbolEffect(.bounce, value: appeared && !reduceMotion)
                .accessibilityHidden(true)
            Text(headline)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            Text("Session saved to your history.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var headline: String {
        summary.personalRecords.isEmpty ? "Great work!" : "New record — nice!"
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
        .padding(.vertical, 16)
        .glassCard()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
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
        VStack(alignment: .leading, spacing: 12) {
            Label("Personal Records", systemImage: "trophy.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.caution)
                .accessibilityAddTraits(.isHeader)
            ForEach(summary.personalRecords) { record in
                PersonalRecordRow(record: record, unit: settings.weightUnit)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundTint: some View {
        LinearGradient(
            colors: [Theme.success.opacity(0.10), .clear],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }
}

private struct PersonalRecordRow: View {
    let record: PersonalRecord
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: record.isFirstTime ? "sparkles" : "arrow.up.forward.circle.fill")
                .font(.title2)
                .foregroundStyle(Theme.caution)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
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
        .padding(16)
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
