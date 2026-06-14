//
//  LiftCalmTests.swift
//  LiftCalmTests
//
//  Unit coverage for the logging/volume math the app's insights depend on.
//

import Testing
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
