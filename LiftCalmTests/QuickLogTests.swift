//
//  QuickLogTests.swift
//  LiftCalmTests
//
//  Covers the pure interpretation helpers behind the natural-language set
//  logger: turning a parsed weight + unit hint into canonical kilograms, and
//  matching a parsed exercise name back to the library.
//

import Testing
@testable import LiftCalm

struct QuickLogTests {
    private let catalog = ["Back Squat", "Barbell Bench Press", "Pull-Up", "Overhead Press"]

    // MARK: - Weight interpretation

    @Test func usesStatedKilograms() {
        // Explicit kg wins even when the user's default is pounds.
        #expect(QuickLogService.kilograms(value: 100, unitHint: "kg", defaultUnit: .pounds) == 100)
    }

    @Test func convertsStatedPounds() {
        let kg = QuickLogService.kilograms(value: 100, unitHint: "lb", defaultUnit: .kilograms)
        #expect(abs(kg - 45.359) < 0.01)
    }

    @Test func fallsBackToDefaultUnitWhenUnstated() {
        // "none" + pounds-preferring user → interpret the number as pounds.
        let asPounds = QuickLogService.kilograms(value: 100, unitHint: "none", defaultUnit: .pounds)
        #expect(abs(asPounds - 45.359) < 0.01)
        // "none" + kg-preferring user → the number is already kilograms.
        #expect(QuickLogService.kilograms(value: 100, unitHint: "none", defaultUnit: .kilograms) == 100)
    }

    @Test func clampsNegativeWeightToZero() {
        #expect(QuickLogService.kilograms(value: -50, unitHint: "kg", defaultUnit: .kilograms) == 0)
    }

    // MARK: - Exercise matching

    @Test func matchesExactAndCaseInsensitive() {
        #expect(QuickLogService.matchIndex(name: "back squat", catalogNames: catalog) == 0)
        #expect(QuickLogService.matchIndex(name: "Barbell Bench Press", catalogNames: catalog) == 1)
    }

    @Test func matchesIgnoringPunctuation() {
        // "PULL UP" → "pullup" matches catalog "Pull-Up" → "pullup".
        #expect(QuickLogService.matchIndex(name: "PULL UP", catalogNames: catalog) == 2)
    }

    @Test func returnsNilForUnknownExercise() {
        #expect(QuickLogService.matchIndex(name: "Zercher Carry", catalogNames: catalog) == nil)
    }

    @Test func returnsNilForEmptyName() {
        #expect(QuickLogService.matchIndex(name: "   ", catalogNames: catalog) == nil)
    }
}
