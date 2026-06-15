//
//  ProgressMetrics.swift
//  LiftCalm
//
//  Pure, testable aggregation behind the Progress charts: per-exercise estimated
//  1RM and volume across finished sessions. Like WorkoutMetrics, this stays free
//  of SwiftUI and store fetches so the unit tests exercise it with plain models.
//  All weights are canonical kilograms; convert at the UI boundary.
//

import Foundation

/// One exercise's standout numbers on a single finished session — the unit
/// plotted on a progress chart (one point per session).
struct ExerciseSessionPoint: Identifiable, Equatable {
    /// The workout's id, so chart identity stays stable across reloads.
    let id: UUID
    /// Session start — the x-axis value.
    let date: Date
    /// Best estimated 1RM achieved for this exercise in the session.
    let bestEstimatedOneRepMaxKilograms: Double
    /// Total qualifying volume (Σ weight × reps) for this exercise in the session.
    let totalVolumeKilograms: Double
    /// The set behind the best 1RM, for the selection callout ("100 kg × 5").
    let bestSetWeightKilograms: Double
    let bestSetReps: Int

    /// The plotted value for a chosen metric, in canonical kilograms.
    func value(for metric: ProgressMetric) -> Double {
        switch metric {
        case .estimatedOneRepMax: bestEstimatedOneRepMaxKilograms
        case .volume: totalVolumeKilograms
        }
    }
}

/// Which series the progress chart is showing. Estimated 1RM tracks strength;
/// volume tracks work done. Both are the proven "is it working?" lenses.
enum ProgressMetric: String, CaseIterable, Identifiable, Sendable {
    case estimatedOneRepMax
    case volume

    var id: String { rawValue }

    var label: String {
        switch self {
        case .estimatedOneRepMax: "Est. 1RM"
        case .volume: "Volume"
        }
    }
}

/// Headline numbers for the selected exercise + metric, shown above the chart.
struct ProgressSummary: Equatable {
    let sessionCount: Int
    /// All-time best of the metric (peak across sessions), in kilograms.
    let bestKilograms: Double
    /// Earliest and latest session values, in kilograms — for the trend delta.
    let firstKilograms: Double
    let latestKilograms: Double

    /// Change from the first logged session to the latest, in kilograms.
    var changeKilograms: Double { latestKilograms - firstKilograms }

    /// Only meaningful with two or more sessions to compare.
    var hasTrend: Bool { sessionCount >= 2 }

    static let empty = ProgressSummary(sessionCount: 0, bestKilograms: 0, firstKilograms: 0, latestKilograms: 0)
}

enum ProgressMetrics {

    /// Exercises that appear in finished history with at least one qualifying set,
    /// most-recently-trained first — the source for the exercise picker.
    static func trackedExercises(in workouts: [Workout]) -> [Exercise] {
        var exercises: [UUID: Exercise] = [:]
        var latestDate: [UUID: Date] = [:]
        for workout in workouts where workout.endedAt != nil {
            for entry in workout.entries {
                guard let exercise = entry.exercise,
                      entry.sets.contains(where: \.countsTowardMetrics) else { continue }
                exercises[exercise.id] = exercise
                latestDate[exercise.id] = max(latestDate[exercise.id] ?? .distantPast, workout.startedAt)
            }
        }
        return exercises.values.sorted {
            (latestDate[$0.id] ?? .distantPast) > (latestDate[$1.id] ?? .distantPast)
        }
    }

    /// Ascending-by-date series of one exercise's per-session bests across the
    /// given workouts. Only finished sessions with a qualifying set for the
    /// exercise contribute a point. Pure over the passed-in data so it's
    /// unit-testable without a store.
    static func sessionPoints(forExercise exerciseID: UUID, in workouts: [Workout]) -> [ExerciseSessionPoint] {
        var points: [ExerciseSessionPoint] = []
        for workout in workouts where workout.endedAt != nil {
            var best1RM = 0.0
            var volume = 0.0
            var bestSetWeight = 0.0
            var bestSetReps = 0
            var hasQualifying = false

            for entry in workout.entries where entry.exercise?.id == exerciseID {
                for set in entry.sets where set.countsTowardMetrics {
                    hasQualifying = true
                    volume += set.volume
                    let oneRepMax = set.estimatedOneRepMax
                    if oneRepMax > best1RM {
                        best1RM = oneRepMax
                        bestSetWeight = set.weightKilograms
                        bestSetReps = set.reps
                    }
                }
            }

            guard hasQualifying else { continue }
            points.append(ExerciseSessionPoint(
                id: workout.id,
                date: workout.startedAt,
                bestEstimatedOneRepMaxKilograms: best1RM,
                totalVolumeKilograms: volume,
                bestSetWeightKilograms: bestSetWeight,
                bestSetReps: bestSetReps
            ))
        }
        return points.sorted { $0.date < $1.date }
    }

    /// Reduces a session series into the headline summary for a metric. Assumes
    /// `points` is date-ascending (as returned by `sessionPoints`).
    static func summary(of points: [ExerciseSessionPoint], metric: ProgressMetric) -> ProgressSummary {
        guard let first = points.first, let last = points.last else { return .empty }
        let values = points.map { $0.value(for: metric) }
        return ProgressSummary(
            sessionCount: points.count,
            bestKilograms: values.max() ?? 0,
            firstKilograms: first.value(for: metric),
            latestKilograms: last.value(for: metric)
        )
    }
}
