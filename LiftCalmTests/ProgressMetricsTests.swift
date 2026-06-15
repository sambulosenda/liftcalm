//
//  ProgressMetricsTests.swift
//  LiftCalmTests
//
//  Coverage for the per-exercise progression aggregation behind the Progress
//  charts. Pure over plain models — no store, no SwiftUI.
//

import Testing
import Foundation
@testable import LiftCalm

struct ProgressMetricsTests {

    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    /// Builds a finished workout for one exercise. Working sets are `(weight, reps)`;
    /// warm-ups are flagged so they're excluded from metrics.
    private func finishedWorkout(
        _ exercise: Exercise,
        daysAgo: Int,
        sets: [(Double, Int)],
        warmups: [(Double, Int)] = []
    ) -> Workout {
        let date = epoch.addingTimeInterval(TimeInterval(-daysAgo * 86_400))
        var entrySets: [SetEntry] = []
        var order = 0
        for (weight, reps) in warmups {
            entrySets.append(SetEntry(order: order, weightKilograms: weight, reps: reps, isCompleted: true, isWarmup: true))
            order += 1
        }
        for (weight, reps) in sets {
            entrySets.append(SetEntry(order: order, weightKilograms: weight, reps: reps, isCompleted: true))
            order += 1
        }
        let entry = ExerciseEntry(order: 0, exercise: exercise, sets: entrySets)
        return Workout(startedAt: date, endedAt: date.addingTimeInterval(3000), entries: [entry])
    }

    // MARK: - Tracked exercises

    @Test func tracksExercisesMostRecentFirst() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let squat = Exercise(name: "Squat", muscleGroup: .quads, equipment: .barbell)
        let benchDay = finishedWorkout(bench, daysAgo: 10, sets: [(60, 5)])
        let squatDay = finishedWorkout(squat, daysAgo: 2, sets: [(100, 5)])

        let tracked = ProgressMetrics.trackedExercises(in: [benchDay, squatDay])
        #expect(tracked.map(\.id) == [squat.id, bench.id])
    }

    @Test func trackedExercisesExcludesUnfinishedAndWarmupOnly() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let active = Workout(startedAt: epoch, endedAt: nil, entries: [
            ExerciseEntry(order: 0, exercise: bench, sets: [
                SetEntry(order: 0, weightKilograms: 60, reps: 5, isCompleted: true),
            ]),
        ])
        let warmupOnly = finishedWorkout(bench, daysAgo: 1, sets: [], warmups: [(40, 5)])

        #expect(ProgressMetrics.trackedExercises(in: [active, warmupOnly]).isEmpty)
    }

    // MARK: - Session points

    @Test func sessionPointsAreDateAscendingWithCorrectBests() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let older = finishedWorkout(bench, daysAgo: 10, sets: [(60, 5), (62.5, 5)])
        let newer = finishedWorkout(bench, daysAgo: 2, sets: [(70, 3)])

        let points = ProgressMetrics.sessionPoints(forExercise: bench.id, in: [newer, older])
        #expect(points.count == 2)
        #expect(points.map(\.date) == points.map(\.date).sorted())

        // Older session's best set is 62.5 × 5; volume = 60*5 + 62.5*5 = 612.5.
        let first = points.first
        #expect(first?.bestSetWeightKilograms == 62.5)
        #expect(first?.bestSetReps == 5)
        #expect(first?.totalVolumeKilograms == 612.5)
        let expected1RM = WorkoutMetrics.estimatedOneRepMax(weightKilograms: 62.5, reps: 5)
        #expect(abs((first?.bestEstimatedOneRepMaxKilograms ?? 0) - expected1RM) < 0.0001)
    }

    @Test func sessionPointsSkipSessionsWithoutTheExercise() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let squat = Exercise(name: "Squat", muscleGroup: .quads, equipment: .barbell)
        let benchDay = finishedWorkout(bench, daysAgo: 5, sets: [(60, 5)])
        let squatDay = finishedWorkout(squat, daysAgo: 3, sets: [(100, 5)])

        #expect(ProgressMetrics.sessionPoints(forExercise: bench.id, in: [benchDay, squatDay]).count == 1)
    }

    @Test func sessionPointsExcludeWarmupsFromBestsAndVolume() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        // A heavy 200 kg warm-up single must not inflate the best 1RM or volume.
        let day = finishedWorkout(bench, daysAgo: 1, sets: [(60, 5)], warmups: [(200, 1)])

        let points = ProgressMetrics.sessionPoints(forExercise: bench.id, in: [day])
        #expect(points.count == 1)
        #expect(points.first?.bestSetWeightKilograms == 60)
        #expect(points.first?.totalVolumeKilograms == 300)
    }

    // MARK: - Summary

    @Test func summaryComputesPeakAndTrend() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let first = finishedWorkout(bench, daysAgo: 9, sets: [(60, 5)])
        let peak = finishedWorkout(bench, daysAgo: 6, sets: [(80, 5)])
        let latest = finishedWorkout(bench, daysAgo: 2, sets: [(70, 5)])

        let points = ProgressMetrics.sessionPoints(forExercise: bench.id, in: [first, peak, latest])
        let summary = ProgressMetrics.summary(of: points, metric: .estimatedOneRepMax)

        #expect(summary.sessionCount == 3)
        #expect(summary.hasTrend)
        let expectedPeak = WorkoutMetrics.estimatedOneRepMax(weightKilograms: 80, reps: 5)
        #expect(abs(summary.bestKilograms - expectedPeak) < 0.0001)
        #expect(summary.changeKilograms > 0) // 60 → 70 over the span
    }

    @Test func summaryTracksVolumeChange() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let lighter = finishedWorkout(bench, daysAgo: 4, sets: [(60, 5)])          // 300
        let heavier = finishedWorkout(bench, daysAgo: 1, sets: [(60, 5), (60, 5)]) // 600

        let points = ProgressMetrics.sessionPoints(forExercise: bench.id, in: [lighter, heavier])
        let summary = ProgressMetrics.summary(of: points, metric: .volume)

        #expect(summary.bestKilograms == 600)
        #expect(summary.firstKilograms == 300)
        #expect(summary.latestKilograms == 600)
        #expect(summary.changeKilograms == 300)
    }

    @Test func emptySummaryHasNoTrend() {
        let summary = ProgressMetrics.summary(of: [], metric: .volume)
        #expect(summary == .empty)
        #expect(!summary.hasTrend)
    }

    @Test func pointValueSelectsTheMetricField() {
        let point = ExerciseSessionPoint(
            id: UUID(), date: epoch,
            bestEstimatedOneRepMaxKilograms: 100, totalVolumeKilograms: 500,
            bestSetWeightKilograms: 90, bestSetReps: 3
        )
        #expect(point.value(for: .estimatedOneRepMax) == 100)
        #expect(point.value(for: .volume) == 500)
    }
}
