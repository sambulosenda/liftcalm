//
//  Workout.swift
//  LiftCalm
//
//  A logged training session and its nested entries. Weights stored in kg.
//
//  Relationship shape:
//    Workout 1—* ExerciseEntry 1—* SetEntry
//  Deletes cascade downward so removing a workout cleans up everything under it.
//

import Foundation
import SwiftData

@Model
final class Workout {
    // No `.unique` — CloudKit forbids unique constraints. Non-optional stored
    // properties carry defaults (also a CloudKit requirement).
    var id: UUID = UUID()
    /// When the session began. Also the date used for history grouping.
    var startedAt: Date = Date()
    /// Set when the user finishes. `nil` means the session is still active.
    var endedAt: Date?
    var notes: String = ""
    var energyRaw: Int?
    /// Name carried over from the template the session started from, if any.
    var templateName: String?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var entries: [ExerciseEntry] = []

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        notes: String = "",
        energy: EnergyLevel? = nil,
        templateName: String? = nil,
        entries: [ExerciseEntry] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.energyRaw = energy?.rawValue
        self.templateName = templateName
        self.entries = entries
    }

    /// Self-reported energy for the session.
    var energy: EnergyLevel? {
        get { energyRaw.flatMap(EnergyLevel.init(rawValue:)) }
        set { energyRaw = newValue?.rawValue }
    }

    var isActive: Bool { endedAt == nil }

    /// Entries in user-defined order (model arrays are unordered in SwiftData).
    var orderedEntries: [ExerciseEntry] {
        entries.sorted { $0.order < $1.order }
    }
}

@Model
final class ExerciseEntry {
    var id: UUID = UUID()
    /// Position within the workout.
    var order: Int = 0
    var notes: String = ""

    /// The library movement being performed. The nullify delete rule lives on the
    /// inverse (`Exercise.loggedEntries`) so deleting a library exercise preserves
    /// logged history.
    var exercise: Exercise?

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.entry)
    var sets: [SetEntry] = []

    init(
        id: UUID = UUID(),
        order: Int,
        exercise: Exercise?,
        notes: String = "",
        sets: [SetEntry] = []
    ) {
        self.id = id
        self.order = order
        self.exercise = exercise
        self.notes = notes
        self.sets = sets
    }

    var orderedSets: [SetEntry] {
        sets.sorted { $0.order < $1.order }
    }
}

@Model
final class SetEntry {
    var id: UUID = UUID()
    var order: Int = 0
    /// Canonical load in kilograms. Convert at the UI boundary for display/entry.
    var weightKilograms: Double = 0
    var reps: Int = 0
    /// Rate of perceived exertion, 1–10. Optional — many sets won't record it.
    var rpe: Double?
    /// Logged sets count toward volume/PRs; planned-but-unfinished sets don't.
    var isCompleted: Bool = false
    var isWarmup: Bool = false

    var entry: ExerciseEntry?

    init(
        id: UUID = UUID(),
        order: Int,
        weightKilograms: Double = 0,
        reps: Int = 0,
        rpe: Double? = nil,
        isCompleted: Bool = false,
        isWarmup: Bool = false
    ) {
        self.id = id
        self.order = order
        self.weightKilograms = weightKilograms
        self.reps = reps
        self.rpe = rpe
        self.isCompleted = isCompleted
        self.isWarmup = isWarmup
    }
}
