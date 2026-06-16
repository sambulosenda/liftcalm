//
//  RoutineWizardTests.swift
//  LiftCalmTests
//
//  Covers the name-resolver that maps the on-device model's exercise names back
//  to real library rows. This is the safety net that stops a hallucinated or
//  duplicated name from entering the user's data.
//

import Testing
@testable import LiftCalm

struct RoutineWizardTests {
    private let catalog = ["Barbell Bench Press", "Overhead Press", "Back Squat", "Deadlift", "Pull-Up"]

    @Test func resolvesExactNamesToIndices() {
        let out = RoutineWizardService.resolved([("Back Squat", 4), ("Deadlift", 3)], catalogNames: catalog)
        #expect(out.map(\.index) == [2, 3])
        #expect(out.map(\.targetSets) == [4, 3])
    }

    @Test func matchesIgnoringCaseAndPunctuation() {
        // "PULL UP" → "pullup" must match catalog "Pull-Up" → "pullup".
        let out = RoutineWizardService.resolved([("barbell bench press", 3), ("PULL UP", 3)], catalogNames: catalog)
        #expect(out.map(\.index) == [0, 4])
    }

    @Test func dropsNamesNotInCatalog() {
        let out = RoutineWizardService.resolved([("Back Squat", 3), ("Super Squat 3000", 3)], catalogNames: catalog)
        #expect(out.map(\.index) == [2])
    }

    @Test func dropsDuplicatesKeepingFirst() {
        let out = RoutineWizardService.resolved([("Back Squat", 3), ("back squat", 5)], catalogNames: catalog)
        #expect(out.count == 1)
        #expect(out[0].targetSets == 3)
    }

    @Test func clampsSetsToSaneRange() {
        let out = RoutineWizardService.resolved([("Deadlift", 0), ("Back Squat", 99)], catalogNames: catalog)
        #expect(out.map(\.targetSets) == [1, 10])
    }

    @Test func emptyInputYieldsNothing() {
        #expect(RoutineWizardService.resolved([], catalogNames: catalog).isEmpty)
    }
}
