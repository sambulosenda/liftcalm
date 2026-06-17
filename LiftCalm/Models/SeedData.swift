//
//  SeedData.swift
//  LiftCalm
//
//  First-launch population of the exercise library and starter templates.
//  Idempotent: seeded rows use deterministic UUIDs derived from a stable key,
//  so re-running insert-if-missing never duplicates built-ins.
//

import Foundation
import SwiftData

enum SeedData {

    /// Deterministic UUID from a stable string key (FNV-1a → 128 bits).
    /// Lets seeded exercises keep the same id across launches and devices so
    /// templates can reference them and re-seeds stay idempotent.
    static func stableID(_ key: String) -> UUID {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        var second: UInt64 = hash ^ 0x9e3779b97f4a7c15
        second = second &* 0x100000001b3

        var bytes = [UInt8](repeating: 0, count: 16)
        for i in 0..<8 {
            bytes[i] = UInt8(truncatingIfNeeded: hash >> (8 * i))
            bytes[8 + i] = UInt8(truncatingIfNeeded: second >> (8 * i))
        }
        return bytes.withUnsafeBytes { raw in
            NSUUID(uuidBytes: raw.bindMemory(to: UInt8.self).baseAddress) as UUID
        }
    }

    // MARK: - Library

    /// Built-in movements. Keep names canonical; users add their own variants.
    static let builtInExercises: [Exercise] = {
        func ex(
            _ name: String,
            _ muscle: MuscleGroup,
            _ equip: Equipment,
            secondary: [MuscleGroup] = []
        ) -> Exercise {
            Exercise(
                id: stableID("ex:\(name)"),
                name: name,
                muscleGroup: muscle,
                equipment: equip,
                secondaryMuscles: secondary
            )
        }
        return [
            // Push
            ex("Barbell Bench Press", .chest, .barbell, secondary: [.triceps, .shoulders]),
            ex("Incline Dumbbell Press", .chest, .dumbbell, secondary: [.shoulders, .triceps]),
            ex("Cable Fly", .chest, .cable, secondary: [.shoulders]),
            ex("Overhead Press", .shoulders, .barbell, secondary: [.triceps, .chest]),
            ex("Dumbbell Lateral Raise", .shoulders, .dumbbell),
            ex("Triceps Pushdown", .triceps, .cable),
            ex("Overhead Triceps Extension", .triceps, .dumbbell),
            // Pull
            ex("Deadlift", .back, .barbell, secondary: [.hamstrings, .glutes, .core]),
            ex("Pull-Up", .back, .bodyweight, secondary: [.biceps]),
            ex("Bent-Over Row", .back, .barbell, secondary: [.biceps]),
            ex("Lat Pulldown", .back, .cable, secondary: [.biceps]),
            ex("Seated Cable Row", .back, .cable, secondary: [.biceps]),
            ex("Barbell Curl", .biceps, .barbell),
            ex("Dumbbell Hammer Curl", .biceps, .dumbbell),
            // Legs
            ex("Back Squat", .quads, .barbell, secondary: [.glutes, .hamstrings, .core]),
            ex("Front Squat", .quads, .barbell, secondary: [.glutes, .core]),
            ex("Leg Press", .quads, .machine, secondary: [.glutes, .hamstrings]),
            ex("Romanian Deadlift", .hamstrings, .barbell, secondary: [.glutes, .back]),
            ex("Leg Curl", .hamstrings, .machine),
            ex("Hip Thrust", .glutes, .barbell, secondary: [.hamstrings]),
            ex("Walking Lunge", .glutes, .dumbbell, secondary: [.quads, .hamstrings]),
            ex("Standing Calf Raise", .calves, .machine),
            // Core / full body
            ex("Plank", .core, .bodyweight, secondary: [.shoulders]),
            ex("Hanging Leg Raise", .core, .bodyweight),
            ex("Kettlebell Swing", .fullBody, .kettlebell, secondary: [.glutes, .hamstrings, .back, .shoulders]),
        ]
    }()

    // MARK: - Templates

    /// Built-in starter routines, defined by exercise name + target sets.
    private static let templateBlueprints: [(name: String, summary: String, items: [(String, Int)])] = [
        ("Push", "Chest, shoulders, triceps", [
            ("Barbell Bench Press", 4),
            ("Overhead Press", 3),
            ("Incline Dumbbell Press", 3),
            ("Dumbbell Lateral Raise", 3),
            ("Triceps Pushdown", 3),
        ]),
        ("Pull", "Back and biceps", [
            ("Deadlift", 3),
            ("Pull-Up", 3),
            ("Seated Cable Row", 3),
            ("Lat Pulldown", 3),
            ("Barbell Curl", 3),
        ]),
        ("Legs", "Quads, hamstrings, glutes", [
            ("Back Squat", 4),
            ("Romanian Deadlift", 3),
            ("Leg Press", 3),
            ("Leg Curl", 3),
            ("Standing Calf Raise", 4),
        ]),
        ("Full Body", "A balanced whole-body session", [
            ("Back Squat", 3),
            ("Barbell Bench Press", 3),
            ("Bent-Over Row", 3),
            ("Overhead Press", 3),
            ("Plank", 3),
        ]),
    ]

    // MARK: - Seeding

    /// Inserts any missing built-in exercises and templates. Safe to call on
    /// every launch; only inserts what isn't already present.
    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        seedExercises(context)
        seedTemplates(context)
        try? context.save()
    }

    @MainActor
    private static func seedExercises(_ context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let existingIDs = Set(existing.map(\.id))
        for exercise in builtInExercises where !existingIDs.contains(exercise.id) {
            context.insert(exercise)
        }
    }

    @MainActor
    private static func seedTemplates(_ context: ModelContext) {
        let existingTemplates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        let existingNames = Set(existingTemplates.filter(\.isBuiltIn).map(\.name))

        // Resolve exercises by their deterministic id so templates link correctly.
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id, $0) })

        for blueprint in templateBlueprints where !existingNames.contains(blueprint.name) {
            let template = WorkoutTemplate(
                id: stableID("tmpl:\(blueprint.name)"),
                name: blueprint.name,
                summary: blueprint.summary,
                isBuiltIn: true
            )
            context.insert(template)
            for (index, item) in blueprint.items.enumerated() {
                guard let exercise = byID[stableID("ex:\(item.0)")] else { continue }
                let templateItem = TemplateItem(
                    order: index,
                    targetSets: item.1,
                    exercise: exercise
                )
                templateItem.template = template
                context.insert(templateItem)
            }
        }
    }
}
