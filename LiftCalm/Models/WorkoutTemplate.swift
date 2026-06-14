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
    @Attribute(.unique) var id: UUID
    var name: String
    var summary: String
    /// True for the built-in starter templates seeded on first launch.
    var isBuiltIn: Bool

    @Relationship(deleteRule: .cascade, inverse: \TemplateItem.template)
    var items: [TemplateItem]

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
    @Attribute(.unique) var id: UUID
    var order: Int
    /// Suggested number of working sets to pre-fill when the session starts.
    var targetSets: Int

    @Relationship(deleteRule: .nullify)
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
