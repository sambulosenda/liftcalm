//
//  HistoryView.swift
//  LiftCalm
//
//  Chronological list of finished sessions, newest first, with a lightweight
//  volume trend across recent workouts.
//

import SwiftUI
import SwiftData
import Charts

struct HistoryView: View {
    @Query(
        filter: #Predicate<Workout> { $0.endedAt != nil },
        sort: \Workout.startedAt, order: .reverse
    )
    private var workouts: [Workout]

    @Environment(AppSettings.self) private var settings

    var body: some View {
        NavigationStack {
            Group {
                if workouts.isEmpty {
                    ContentUnavailableView(
                        "No history yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finish a workout and it'll show up here.")
                    )
                } else {
                    List {
                        if workouts.count >= 2 {
                            Section("Volume Trend") {
                                VolumeTrendChart(workouts: Array(workouts.prefix(12)).reversed())
                                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }
                        Section("Sessions") {
                            ForEach(workouts) { workout in
                                NavigationLink {
                                    WorkoutDetailView(workout: workout)
                                } label: {
                                    HistoryRow(workout: workout)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}

/// Compact bar chart of total volume per recent session.
private struct VolumeTrendChart: View {
    let workouts: [Workout]
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Chart(workouts) { workout in
            BarMark(
                x: .value("Date", workout.startedAt, unit: .day),
                y: .value("Volume", settings.weightUnit.fromKilograms(workout.totalVolume))
            )
            .foregroundStyle(Theme.accent.gradient)
            .cornerRadius(4)
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let volume = value.as(Double.self) {
                        Text(volume.formatted(.number.notation(.compactName)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 160)
        .accessibilityLabel("Volume per session over recent workouts")
    }
}

private struct HistoryRow: View {
    let workout: Workout
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 1) {
                Text(workout.startedAt, format: .dateTime.day())
                    .font(.headline.monospacedDigit())
                Text(workout.startedAt, format: .dateTime.month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 3) {
                Text(workout.templateName ?? "Workout")
                    .font(.headline)
                HStack(spacing: 8) {
                    Label("\(workout.exerciseCount)", systemImage: "list.bullet")
                    Label("\(workout.completedSetCount)", systemImage: "checkmark")
                    if let duration = workout.duration {
                        Label(Formatting.duration(duration), systemImage: "clock")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Formatting.volume(workout.totalVolume, unit: settings.weightUnit))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HistoryView()
        .modelContainer(PreviewData.container)
        .environment(AppSettings())
}
