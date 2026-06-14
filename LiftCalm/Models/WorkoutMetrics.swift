//
//  WorkoutMetrics.swift
//  LiftCalm
//
//  Pure, testable calculations over logged data. Kept free of SwiftUI and
//  SwiftData fetch logic so the unit tests can exercise them directly with
//  plain values. All weights are in canonical kilograms.
//

import Foundation

enum WorkoutMetrics {

    /// Estimated one-rep max via the Epley formula.
    /// 1RM = w · (1 + reps/30). A single rep returns the weight itself.
    /// Returns 0 for non-positive weight or reps so callers can sum safely.
    static func estimatedOneRepMax(weightKilograms weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Volume load for a single set: weight × reps.
    static func setVolume(weightKilograms weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        return weight * Double(reps)
    }

    /// Detects estimated-1RM personal records set in `workout`, comparing each
    /// exercise against its best qualifying set across `history` (prior finished
    /// workouts, excluding this one). One record per exercise. An exercise with
    /// no prior history is flagged as a first-time record.
    ///
    /// Pure over the passed-in data so it's unit-testable without a store.
    static func detectPersonalRecords(
        for workout: Workout,
        history: [Workout]
    ) -> [PersonalRecord] {
        // Best historical estimated 1RM per exercise id.
        var historicalBest: [UUID: Double] = [:]
        for past in history {
            for entry in past.entries {
                guard let id = entry.exercise?.id else { continue }
                for set in entry.sets where set.countsTowardMetrics {
                    historicalBest[id] = max(historicalBest[id] ?? 0, set.estimatedOneRepMax)
                }
            }
        }

        // Best estimated 1RM achieved in this workout per exercise id.
        var currentBest: [UUID: (name: String, value: Double)] = [:]
        for entry in workout.entries {
            guard let exercise = entry.exercise else { continue }
            for set in entry.sets where set.countsTowardMetrics {
                let best = currentBest[exercise.id]?.value ?? 0
                if set.estimatedOneRepMax > best {
                    currentBest[exercise.id] = (exercise.name, set.estimatedOneRepMax)
                }
            }
        }

        var records: [PersonalRecord] = []
        for (id, current) in currentBest {
            let prior = historicalBest[id]
            guard current.value > (prior ?? 0) else { continue }
            records.append(
                PersonalRecord(
                    id: id,
                    exerciseName: current.name,
                    estimatedOneRepMaxKilograms: current.value,
                    isFirstTime: prior == nil
                )
            )
        }
        // Strongest lifts first.
        return records.sorted { $0.estimatedOneRepMaxKilograms > $1.estimatedOneRepMaxKilograms }
    }
}

/// An estimated-1RM personal record hit in a session.
struct PersonalRecord: Identifiable, Equatable {
    /// The exercise's id (one record per exercise).
    let id: UUID
    let exerciseName: String
    let estimatedOneRepMaxKilograms: Double
    /// True when this is the first time the exercise was logged.
    let isFirstTime: Bool
}

// MARK: - Model conveniences

extension SetEntry {
    /// Counts toward metrics only when completed, not a warm-up, and with at
    /// least one rep logged. Weight may be 0 (bodyweight moves still count as a
    /// set); a set with 0 reps is empty and must not inflate counts or PRs.
    var countsTowardMetrics: Bool { isCompleted && !isWarmup && reps > 0 }

    var volume: Double {
        guard countsTowardMetrics else { return 0 }
        return WorkoutMetrics.setVolume(weightKilograms: weightKilograms, reps: reps)
    }

    var estimatedOneRepMax: Double {
        guard countsTowardMetrics else { return 0 }
        return WorkoutMetrics.estimatedOneRepMax(weightKilograms: weightKilograms, reps: reps)
    }
}

extension ExerciseEntry {
    /// Total volume across this exercise's qualifying sets.
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.volume }
    }

    /// Number of completed working sets.
    var completedSetCount: Int {
        sets.filter(\.countsTowardMetrics).count
    }

    /// Best estimated 1RM among this exercise's sets — the session PR candidate.
    var bestEstimatedOneRepMax: Double {
        sets.map(\.estimatedOneRepMax).max() ?? 0
    }
}

extension Workout {
    /// Total volume load for the whole session.
    var totalVolume: Double {
        entries.reduce(0) { $0 + $1.totalVolume }
    }

    /// Count of completed working sets in the session.
    var completedSetCount: Int {
        entries.reduce(0) { $0 + $1.completedSetCount }
    }

    var exerciseCount: Int { entries.count }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    /// Share of session volume per muscle region, for the balance summary.
    /// Returns an empty dictionary when nothing qualifying was logged.
    func volumeByRegion() -> [MuscleGroup.Region: Double] {
        var totals: [MuscleGroup.Region: Double] = [:]
        for entry in entries {
            guard let region = entry.exercise?.muscleGroup.region else { continue }
            totals[region, default: 0] += entry.totalVolume
        }
        return totals.filter { $0.value > 0 }
    }
}
