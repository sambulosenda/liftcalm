//
//  WorkoutDetailView.swift
//  LiftCalm
//
//  Read-only breakdown of a finished session: summary, muscle balance, and the
//  full set log per exercise.
//

import SwiftUI
import SwiftData

struct WorkoutDetailView: View {
    let workout: Workout
    @Environment(AppSettings.self) private var settings

    var body: some View {
        List {
            Section {
                summaryGrid
                    .listRowBackground(Color.clear)
            }

            let balance = workout.volumeByRegion()
            if !balance.isEmpty {
                Section("Muscle Balance") {
                    MuscleBalanceView(volumeByRegion: balance, unit: settings.weightUnit)
                        .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                }
            }

            ForEach(workout.orderedEntries) { entry in
                Section(entry.exercise?.name ?? "Exercise") {
                    ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                        LoggedSetRow(number: index + 1, set: set, unit: settings.weightUnit)
                    }
                }
            }

            if !workout.notes.isEmpty {
                Section("Notes") { Text(workout.notes) }
            }
        }
        .navigationTitle(workout.templateName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryGrid: some View {
        HStack {
            metric("Volume", Formatting.volume(workout.totalVolume, unit: settings.weightUnit))
            Divider().frame(height: 36)
            metric("Sets", "\(workout.completedSetCount)")
            Divider().frame(height: 36)
            metric("Exercises", "\(workout.exerciseCount)")
            if let duration = workout.duration {
                Divider().frame(height: 36)
                metric("Time", Formatting.duration(duration))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.md)
        .glassCard()
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Per-region volume split shown as proportional calm bars.
private struct MuscleBalanceView: View {
    let volumeByRegion: [MuscleGroup.Region: Double]
    let unit: WeightUnit

    private var total: Double { volumeByRegion.values.reduce(0, +) }
    private let order: [MuscleGroup.Region] = [.upper, .lower, .core]

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            ForEach(order, id: \.self) { region in
                if let value = volumeByRegion[region], value > 0 {
                    HStack(spacing: Theme.Spacing.md) {
                        Text(region.rawValue.capitalized)
                            .font(.subheadline)
                            .frame(width: 64, alignment: .leading)
                        GeometryReader { geo in
                            Capsule()
                                .fill(color(region).gradient)
                                .frame(width: max(6, geo.size.width * fraction(value)))
                        }
                        .frame(height: 12)
                        Text("\(Int((fraction(value) * 100).rounded()))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(region.rawValue), \(Int((fraction(value) * 100).rounded())) percent of volume")
                }
            }
        }
    }

    private func fraction(_ value: Double) -> Double {
        total > 0 ? value / total : 0
    }

    private func color(_ region: MuscleGroup.Region) -> Color {
        switch region {
        case .upper: Theme.accent
        case .lower: Theme.calmBlue
        case .core: Theme.caution
        }
    }
}

private struct LoggedSetRow: View {
    let number: Int
    let set: SetEntry
    let unit: WeightUnit

    var body: some View {
        HStack {
            Text("\(number)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(Formatting.weight(set.weightKilograms, unit: unit))
                .font(.body.monospacedDigit())
            Text("×")
                .foregroundStyle(.secondary)
            Text("\(set.reps)")
                .font(.body.monospacedDigit())
            Spacer()
            if let rpe = set.rpe {
                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.caption)
                    .foregroundStyle(Theme.calmBlue)
            }
            if set.isWarmup {
                Image(systemName: "flame")
                    .font(.caption)
                    .foregroundStyle(Theme.caution)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Set \(number): \(Formatting.weight(set.weightKilograms, unit: unit)) for \(set.reps) reps")
    }
}

#Preview {
    NavigationStack {
        WorkoutDetailView(workout: PreviewData.activeWorkout(in: PreviewData.container.mainContext))
            .modelContainer(PreviewData.container)
            .environment(AppSettings())
    }
}
