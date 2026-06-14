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
    /// is idempotent and templates can reference them reliably.
    @Attribute(.unique) var id: UUID
    var name: String
    var muscleGroup: MuscleGroup
    var equipment: Equipment
    /// True for movements the user added themselves (shown under "My Exercises").
    var isCustom: Bool
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        isCustom: Bool = false,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.muscleGroup = muscleGroup
        self.equipment = equipment
        self.isCustom = isCustom
        self.notes = notes
    }
}
