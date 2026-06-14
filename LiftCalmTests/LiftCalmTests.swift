//
//  LiftCalmTests.swift
//  LiftCalmTests
//
//  Unit coverage for the logging/volume math the app's insights depend on.
//

import Testing
import Foundation
@testable import LiftCalm

struct LiftCalmTests {

    // MARK: - Estimated 1RM (Epley)

    @Test func oneRepMaxSingleRepIsWeight() {
        #expect(WorkoutMetrics.estimatedOneRepMax(weightKilograms: 100, reps: 1) == 100)
    }

    @Test func oneRepMaxEpleyFormula() {
        // 100 * (1 + 5/30) = 116.666...
        let value = WorkoutMetrics.estimatedOneRepMax(weightKilograms: 100, reps: 5)
        #expect(abs(value - 116.6667) < 0.001)
    }

    @Test func oneRepMaxZeroInputsReturnZero() {
        #expect(WorkoutMetrics.estimatedOneRepMax(weightKilograms: 0, reps: 5) == 0)
        #expect(WorkoutMetrics.estimatedOneRepMax(weightKilograms: 100, reps: 0) == 0)
    }

    // MARK: - Set volume

    @Test func setVolumeMultiplies() {
        #expect(WorkoutMetrics.setVolume(weightKilograms: 60, reps: 10) == 600)
    }

    @Test func setVolumeZeroWeightOrRepsIsZero() {
        #expect(WorkoutMetrics.setVolume(weightKilograms: 0, reps: 10) == 0)
        #expect(WorkoutMetrics.setVolume(weightKilograms: 60, reps: 0) == 0)
    }

    // MARK: - Unit conversion

    @Test func kilogramsToPounds() {
        let lb = WeightUnit.pounds.fromKilograms(100)
        #expect(abs(lb - 220.462) < 0.01)
    }

    @Test func kilogramsUnitIsIdentity() {
        #expect(WeightUnit.kilograms.fromKilograms(80) == 80)
        #expect(WeightUnit.kilograms.toKilograms(80) == 80)
    }

    @Test func poundsRoundTripPreservesValue() {
        let original = 142.5
        let roundTrip = WeightUnit.pounds.toKilograms(WeightUnit.pounds.fromKilograms(original))
        #expect(abs(roundTrip - original) < 0.0001)
    }

    // MARK: - Set qualification

    @Test func onlyCompletedNonWarmupSetsCount() {
        let working = SetEntry(order: 0, weightKilograms: 60, reps: 10, isCompleted: true)
        let warmup = SetEntry(order: 1, weightKilograms: 40, reps: 10, isCompleted: true, isWarmup: true)
        let planned = SetEntry(order: 2, weightKilograms: 80, reps: 5, isCompleted: false)

        #expect(working.countsTowardMetrics)
        #expect(!warmup.countsTowardMetrics)
        #expect(!planned.countsTowardMetrics)

        #expect(working.volume == 600)
        #expect(warmup.volume == 0)
        #expect(planned.volume == 0)
    }

    @Test func zeroRepSetDoesNotCountButBodyweightDoes() {
        // 0 reps = empty, must not count even if completed.
        let empty = SetEntry(order: 0, weightKilograms: 50, reps: 0, isCompleted: true)
        #expect(!empty.countsTowardMetrics)

        // Bodyweight: 0 weight is fine as long as reps were logged.
        let bodyweight = SetEntry(order: 1, weightKilograms: 0, reps: 12, isCompleted: true)
        #expect(bodyweight.countsTowardMetrics)
    }

    // MARK: - Aggregation

    @Test func workoutVolumeExcludesWarmupAndIncomplete() {
        let exercise = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let entry = ExerciseEntry(order: 0, exercise: exercise, sets: [
            SetEntry(order: 0, weightKilograms: 60, reps: 10, isCompleted: true),   // 600
            SetEntry(order: 1, weightKilograms: 40, reps: 10, isCompleted: true, isWarmup: true), // excluded
            SetEntry(order: 2, weightKilograms: 80, reps: 5, isCompleted: false),   // excluded
        ])
        let workout = Workout(entries: [entry])

        #expect(workout.totalVolume == 600)
        #expect(workout.completedSetCount == 1)
        #expect(workout.exerciseCount == 1)
    }

    @Test func volumeByRegionGroupsMuscles() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell) // upper
        let squat = Exercise(name: "Squat", muscleGroup: .quads, equipment: .barbell) // lower

        let benchEntry = ExerciseEntry(order: 0, exercise: bench, sets: [
            SetEntry(order: 0, weightKilograms: 50, reps: 10, isCompleted: true), // 500
        ])
        let squatEntry = ExerciseEntry(order: 1, exercise: squat, sets: [
            SetEntry(order: 0, weightKilograms: 100, reps: 5, isCompleted: true), // 500
        ])
        let workout = Workout(entries: [benchEntry, squatEntry])

        let byRegion = workout.volumeByRegion()
        #expect(byRegion[.upper] == 500)
        #expect(byRegion[.lower] == 500)
        #expect(byRegion[.core] == nil)
    }

    // MARK: - Personal records

    private func makeWorkout(_ exercise: Exercise, weightKg: Double, reps: Int, completed: Bool = true) -> Workout {
        let entry = ExerciseEntry(order: 0, exercise: exercise, sets: [
            SetEntry(order: 0, weightKilograms: weightKg, reps: reps, isCompleted: completed),
        ])
        return Workout(endedAt: .now, entries: [entry])
    }

    @Test func firstTimeExerciseIsAPersonalRecord() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let workout = makeWorkout(bench, weightKg: 60, reps: 5)

        let prs = WorkoutMetrics.detectPersonalRecords(for: workout, history: [])
        #expect(prs.count == 1)
        #expect(prs.first?.exerciseName == "Bench")
        #expect(prs.first?.isFirstTime == true)
    }

    @Test func beatingPriorBestIsARecord() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let past = makeWorkout(bench, weightKg: 60, reps: 5)   // e1RM 70
        let now = makeWorkout(bench, weightKg: 70, reps: 5)    // e1RM ~81.7

        let prs = WorkoutMetrics.detectPersonalRecords(for: now, history: [past])
        #expect(prs.count == 1)
        #expect(prs.first?.isFirstTime == false)
    }

    @Test func notBeatingPriorBestIsNoRecord() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let past = makeWorkout(bench, weightKg: 100, reps: 5)
        let now = makeWorkout(bench, weightKg: 60, reps: 5)

        let prs = WorkoutMetrics.detectPersonalRecords(for: now, history: [past])
        #expect(prs.isEmpty)
    }

    @Test func incompleteSetsDoNotCountForPRs() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let workout = makeWorkout(bench, weightKg: 200, reps: 5, completed: false)

        let prs = WorkoutMetrics.detectPersonalRecords(for: workout, history: [])
        #expect(prs.isEmpty)
    }

    // MARK: - Readiness

    @Test func noHistoryReadsAsFreshAndTrainingOnly() {
        let score = ReadinessEngine.compute(load: .fresh)
        #expect(score.isTrainingOnly)
        #expect(score.value >= 80) // fresh → primed/ready
        #expect(score.band == .primed || score.band == .ready)
    }

    @Test func recentHeavyTrainingLowersReadiness() {
        let rested = ReadinessEngine.compute(load: TrainingLoad(
            hoursSinceLastSession: 60, setsLast7Days: 20, avgDailySetsLast28Days: 4))
        let fatigued = ReadinessEngine.compute(load: TrainingLoad(
            hoursSinceLastSession: 1, setsLast7Days: 80, avgDailySetsLast28Days: 4))
        #expect(fatigued.value < rested.value)
    }

    @Test func bandThresholds() {
        #expect(ReadinessBand(score: 39) == .recover)
        #expect(ReadinessBand(score: 40) == .steady)
        #expect(ReadinessBand(score: 60) == .ready)
        #expect(ReadinessBand(score: 80) == .primed)
    }

    @Test func healthSignalsMakeItNotTrainingOnly() {
        var inputs = RecoveryInputs.none
        inputs.sleepHours = 8
        let score = ReadinessEngine.compute(load: .fresh, inputs: inputs)
        #expect(!score.isTrainingOnly)
        #expect(score.components.contains { $0.id == "sleep" })
    }

    @Test func poorSleepDragsScoreDown() {
        let good = ReadinessEngine.compute(
            load: .fresh, inputs: RecoveryInputs(sleepHours: 8))
        let poor = ReadinessEngine.compute(
            load: .fresh, inputs: RecoveryInputs(sleepHours: 3))
        #expect(poor.value < good.value)
    }

    @Test func trainingLoadFromWorkoutsCountsRecentSets() {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let now = Date(timeIntervalSince1970: 1_000_000)
        let recent = Workout(
            startedAt: now.addingTimeInterval(-86_400), // 1 day ago
            endedAt: now.addingTimeInterval(-86_000),
            entries: [ExerciseEntry(order: 0, exercise: bench, sets: [
                SetEntry(order: 0, weightKilograms: 60, reps: 5, isCompleted: true),
                SetEntry(order: 1, weightKilograms: 60, reps: 5, isCompleted: true),
            ])]
        )
        let old = Workout(
            startedAt: now.addingTimeInterval(-40 * 86_400), // 40 days ago, outside windows
            endedAt: now.addingTimeInterval(-40 * 86_400 + 3000),
            entries: [ExerciseEntry(order: 0, exercise: bench, sets: [
                SetEntry(order: 0, weightKilograms: 60, reps: 5, isCompleted: true),
            ])]
        )
        let load = TrainingLoad.from(workouts: [recent, old], now: now)
        #expect(load.setsLast7Days == 2)
        #expect(load.hoursSinceLastSession != nil)
        #expect(load.hoursSinceLastSession! < 25)
    }

    // MARK: - Formatting

    @Test func clockFormatsMinutesAndSeconds() {
        #expect(Formatting.clock(65) == "1:05")
        #expect(Formatting.clock(0) == "0:00")
        #expect(Formatting.clock(-5) == "0:00") // never negative
    }

    // MARK: - Deterministic seed IDs

    @Test func seedIDsAreStableAndDistinct() {
        #expect(SeedData.stableID("ex:Back Squat") == SeedData.stableID("ex:Back Squat"))
        #expect(SeedData.stableID("ex:Back Squat") != SeedData.stableID("ex:Bench Press"))
    }
}
