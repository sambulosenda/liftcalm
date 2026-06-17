//
//  Exercise.swift
//  LiftCalm
//
//  A movement in the library. Either seeded (built-in) or user-created.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    /// Stable identity. Seeded exercises use deterministic UUIDs so re-seeding
    /// is idempotent and templates can reference them reliably. No `.unique`
    /// constraint — CloudKit forbids it; `SeedData` dedupes by id explicitly.
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroup: MuscleGroup = MuscleGroup.other
    /// Synergist muscles the movement also trains, beyond the primary
    /// `muscleGroup`. Drives the muscle-activation map (a compound like the
    /// bench press lights triceps/shoulders, not just the chest). Empty for
    /// isolation moves. Default `[]` keeps the property CloudKit-safe.
    var secondaryMuscles: [MuscleGroup] = []
    var equipment: Equipment = Equipment.other
    /// True for movements the user added themselves (shown under "My Exercises").
    var isCustom: Bool = false
    var notes: String = ""

    // Inverse relationships — required for CloudKit. Nullify so removing a library
    // movement preserves logged history and template structure rather than
    // cascade-deleting it. These are never read directly; they exist for the link.
    @Relationship(deleteRule: .nullify, inverse: \ExerciseEntry.exercise)
    var loggedEntries: [ExerciseEntry] = []
    @Relationship(deleteRule: .nullify, inverse: \TemplateItem.exercise)
    var templateItems: [TemplateItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        secondaryMuscles: [MuscleGroup] = [],
        isCustom: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.secondaryMuscles = secondaryMuscles
        self.equipment = equipment
        self.isCustom = isCustom
        self.notes = notes
    }
}
