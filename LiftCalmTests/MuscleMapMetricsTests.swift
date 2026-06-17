//
//  MuscleMapMetricsTests.swift
//  LiftCalmTests
//
//  Coverage for the effective-sets-per-muscle distribution behind the
//  activation map. Pure over plain contributions — no store, no SwiftUI,
//  no MuscleMap SDK.
//

import Testing
import Foundation
@testable import LiftCalm

struct MuscleMapMetricsTests {

    private typealias Contribution = WorkoutMetrics.MuscleContribution

    // MARK: - Distribution

    @Test("Primary muscle gets full set credit")
    func primaryFullCredit() {
        let result = WorkoutMetrics.muscleSets(from: [
            Contribution(primary: .chest, secondaries: [], sets: 4)
        ])
        #expect(result == [.chest: 4])
    }

    @Test("Each synergist gets half a set by default")
    func secondaryHalfCredit() {
        let result = WorkoutMetrics.muscleSets(from: [
            Contribution(primary: .chest, secondaries: [.triceps, .shoulders], sets: 4)
        ])
        #expect(result[.chest] == 4)
        #expect(result[.triceps] == 2)
        #expect(result[.shoulders] == 2)
    }

    @Test("Sets accumulate across exercises that share a muscle")
    func musclesAccumulate() {
        // Bench (chest primary, triceps synergist) + a triceps isolation move.
        let result = WorkoutMetrics.muscleSets(from: [
            Contribution(primary: .chest, secondaries: [.triceps], sets: 4),
            Contribution(primary: .triceps, secondaries: [], sets: 3)
        ])
        #expect(result[.chest] == 4)
        #expect(result[.triceps] == 5) // 2 synergist + 3 primary
    }

    @Test("Non-positive sets contribute nothing")
    func zeroSetsDropped() {
        let result = WorkoutMetrics.muscleSets(from: [
            Contribution(primary: .chest, secondaries: [.triceps], sets: 0),
            Contribution(primary: .back, secondaries: [], sets: -2)
        ])
        #expect(result.isEmpty)
    }

    @Test("No contributions yields an empty map")
    func emptyInput() {
        #expect(WorkoutMetrics.muscleSets(from: []).isEmpty)
    }

    @Test("Secondary factor is configurable")
    func customSecondaryFactor() {
        let result = WorkoutMetrics.muscleSets(
            from: [Contribution(primary: .chest, secondaries: [.triceps], sets: 4)],
            secondaryFactor: 0.25
        )
        #expect(result[.triceps] == 1)
    }

    @Test("fullBody and other pass through untranslated at the metric layer")
    func specialGroupsPassThrough() {
        // Anatomical translation (.other dropped, .fullBody spread) is the map
        // layer's job; the pure metric keeps every group it's given.
        let result = WorkoutMetrics.muscleSets(from: [
            Contribution(primary: .fullBody, secondaries: [.other], sets: 2)
        ])
        #expect(result[.fullBody] == 2)
        #expect(result[.other] == 1)
    }

    // MARK: - Seeding

    @Test("Compound lifts seed synergists; isolation moves don't")
    func seededSecondaries() {
        let byName = Dictionary(
            uniqueKeysWithValues: SeedData.builtInExercises.map { ($0.name, $0) }
        )
        let bench = try! #require(byName["Barbell Bench Press"])
        #expect(bench.secondaryMuscles.contains(.triceps))
        #expect(bench.secondaryMuscles.contains(.shoulders))

        let pushdown = try! #require(byName["Triceps Pushdown"])
        #expect(pushdown.secondaryMuscles.isEmpty)
    }
}
