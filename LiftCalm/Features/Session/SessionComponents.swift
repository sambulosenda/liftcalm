//
//  SessionComponents.swift
//  LiftCalm
//
//  Smaller pieces of the active-workout screen: the live summary header and the
//  per-exercise section header.
//

import SwiftUI

/// Live session stats — duration ticks every second; volume/sets reflect logged
/// work as it's entered.
struct SessionSummaryHeader: View {
    let workout: Workout
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                stat(
                    value: Formatting.duration(context.date.timeIntervalSince(workout.startedAt)),
                    label: "Time"
                )
            }
            Divider().frame(height: 32)
            stat(
                value: Formatting.volume(workout.totalVolume, unit: settings.weightUnit),
                label: "Volume"
            )
            Divider().frame(height: 32)
            stat(value: "\(workout.completedSetCount)", label: "Sets")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .glassCard()
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Exercise title + overflow menu for a workout section.
struct ExerciseSectionHeader: View {
    let entry: ExerciseEntry
    let onRemove: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(entry.exercise?.name ?? "Exercise")
                    .font(.headline)
                    .textCase(nil)
                if let exercise = entry.exercise {
                    Text("\(exercise.muscleGroup.displayName) · \(exercise.equipment.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
            Spacer()
            Menu {
                Button("Remove Exercise", systemImage: "trash", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .accessibilityLabel("Exercise options")
        }
    }
}
