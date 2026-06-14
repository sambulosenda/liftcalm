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
    @Attribute(.unique) var id: UUID
    /// When the session began. Also the date used for history grouping.
    var startedAt: Date
    /// Set when the user finishes. `nil` means the session is still active.
    var endedAt: Date?
    var notes: String
    var energyRaw: Int?
    /// Name carried over from the template the session started from, if any.
    var templateName: String?

    @Relationship(deleteRule: .cascade, inverse: \ExerciseEntry.workout)
    var entries: [ExerciseEntry]

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
    @Attribute(.unique) var id: UUID
    /// Position within the workout.
    var order: Int
    var notes: String

    /// The library movement being performed. Nullify (not cascade) on delete so
    /// deleting an exercise from the library doesn't erase logged history.
    @Relationship(deleteRule: .nullify)
    var exercise: Exercise?

    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.entry)
    var sets: [SetEntry]

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
    @Attribute(.unique) var id: UUID
    var order: Int
    /// Canonical load in kilograms. Convert at the UI boundary for display/entry.
    var weightKilograms: Double
    var reps: Int
    /// Rate of perceived exertion, 1–10. Optional — many sets won't record it.
    var rpe: Double?
    /// Logged sets count toward volume/PRs; planned-but-unfinished sets don't.
    var isCompleted: Bool
    var isWarmup: Bool

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
