//
//  WorkoutTemplate.swift
//  LiftCalm
//
//  A reusable starting point for a session (e.g. Push / Pull / Legs).
//  Starting a workout from a template copies its exercises into a new Workout.
//

import Foundation
import SwiftData

@Model
final class WorkoutTemplate {
    // No `.unique` (CloudKit forbids it); non-optional properties carry defaults.
    var id: UUID = UUID()
    var name: String = ""
    var summary: String = ""
    /// True for the built-in starter templates seeded on first launch.
    var isBuiltIn: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    var items: [TemplateItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        isBuiltIn: Bool = false,
        items: [TemplateItem] = []
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.isBuiltIn = isBuiltIn
        self.items = items
    }

    var orderedItems: [TemplateItem] {
        items.sorted { $0.order < $1.order }
    }
}

@Model
final class TemplateItem {
    var id: UUID = UUID()
    var order: Int = 0
    /// Suggested number of working sets to pre-fill when the session starts.
    var targetSets: Int = 3

    /// The nullify delete rule lives on the inverse (`Exercise.templateItems`).
    var exercise: Exercise?

    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        order: Int,
        targetSets: Int = 3,
        exercise: Exercise?
    ) {
        self.id = id
        self.order = order
        self.targetSets = targetSets
        self.exercise = exercise
    }
}
