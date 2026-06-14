//
//  PreviewData.swift
//  LiftCalm
//
//  Self-contained, in-memory sample data for SwiftUI previews. No live store,
//  no network — every preview builds from this deterministic fixture.
//

import SwiftUI
import SwiftData

@MainActor
enum PreviewData {

    /// Shared in-memory container seeded with built-ins plus a couple of
    /// finished sessions so previews show realistic content.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Workout.self, Exercise.self, WorkoutTemplate.self,
            configurations: config
        )
        let context = container.mainContext
        SeedData.seedIfNeeded(context)
        seedSampleHistory(context)
        return container
    }()

    /// A single in-progress workout for previewing the active session screen.
    static func activeWorkout(in context: ModelContext) -> Workout {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let bench = exercises.first { $0.name == "Barbell Bench Press" }
        let row = exercises.first { $0.name == "Bent-Over Row" }

        let workout = Workout(templateName: "Push")
        context.insert(workout)

        let entry1 = ExerciseEntry(order: 0, exercise: bench)
        entry1.workout = workout
        context.insert(entry1)
        for (i, reps) in [10, 8, 6].enumerated() {
            let set = SetEntry(order: i, weightKilograms: 60 + Double(i) * 5, reps: reps,
                               rpe: 8, isCompleted: i < 2)
            set.entry = entry1
            context.insert(set)
        }

        let entry2 = ExerciseEntry(order: 1, exercise: row)
        entry2.workout = workout
        context.insert(entry2)
        let set = SetEntry(order: 0, weightKilograms: 50, reps: 10)
        set.entry = entry2
        context.insert(set)

        return workout
    }

    private static func seedSampleHistory(_ context: ModelContext) {
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        guard let squat = exercises.first(where: { $0.name == "Back Squat" }),
              let bench = exercises.first(where: { $0.name == "Barbell Bench Press" })
        else { return }

        let calendar = Calendar.current
        for daysAgo in [2, 5, 9] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let workout = Workout(
                startedAt: date,
                endedAt: date.addingTimeInterval(60 * 55),
                energy: .good,
                templateName: daysAgo == 2 ? "Legs" : "Full Body"
            )
            context.insert(workout)
            let entry = ExerciseEntry(order: 0, exercise: daysAgo == 2 ? squat : bench)
            entry.workout = workout
            context.insert(entry)
            for i in 0..<4 {
                let set = SetEntry(
                    order: i,
                    weightKilograms: 80 + Double(i) * 2.5,
                    reps: 5,
                    isCompleted: true
                )
                set.entry = entry
                context.insert(set)
            }
        }
        try? context.save()
    }
}
