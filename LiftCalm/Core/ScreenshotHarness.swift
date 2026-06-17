//
//  ScreenshotHarness.swift
//  LiftCalm
//
//  DEBUG-only App Store screenshot mode. Launch the app with
//  `-uiScreen <name>` and it seeds rich demo data, unlocks Plus, marks
//  onboarding complete, and renders ONE screen full-frame so `simctl io
//  screenshot` can capture it without any UI automation.
//
//  Never compiled into Release (whole file is #if DEBUG) and never wired into
//  any user-facing flow — `LiftCalmApp` only routes here when the launch
//  argument is present. Screen names: today, logging, muscle_map, progress,
//  settings, pricing, ai.
//

#if DEBUG
import SwiftUI
import SwiftData

enum ScreenshotHarness {
    /// The screen requested via `-uiScreen <name>`, or nil for the normal app.
    static var requestedScreen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-uiScreen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
}

@MainActor
struct ScreenshotRootView: View {
    let screen: String

    @State private var container: ModelContainer
    @State private var settings: AppSettings
    @State private var session = SessionController()
    @State private var notifications = NotificationManager()
    @State private var store: StoreManager

    init(screen: String) {
        self.screen = screen
        let container = DemoData.makeContainer(includeInProgress: screen == "logging")
        _container = State(initialValue: container)

        let settings = AppSettings()
        settings.hasCompletedOnboarding = true
        let notifications = NotificationManager()

        // Configure synchronously here (not in .task) so the active workout is
        // resolved before `ActiveWorkoutView` renders — otherwise the logging
        // screen sees a nil session and falls over.
        let session = SessionController()
        session.configure(context: container.mainContext, settings: settings, notifications: notifications)

        _settings = State(initialValue: settings)
        _notifications = State(initialValue: notifications)
        _session = State(initialValue: session)
        // Paywall sells Plus, so it needs a locked store; everything else shows
        // the unlocked, content-rich state.
        _store = State(initialValue: screen == "pricing" ? StoreManager() : .unlockedPreview)
    }

    var body: some View {
        routed
            .environment(settings)
            .environment(session)
            .environment(notifications)
            .environment(store)
            .environment(\.presentPaywall, { _ in })
            .tint(Theme.accent)
            .modelContainer(container)
    }

    @ViewBuilder
    private var routed: some View {
        switch screen {
        case "logging":
            ActiveWorkoutView()
        case "muscle_map":
            MuscleMapSummaryHost(context: container.mainContext)
        case "progress":
            ProgressDashboardView()
        case "settings":
            SettingsView()
        case "pricing":
            PaywallView(context: .charts)
        case "ai", "library":
            LibraryView()
        default: // "today"
            TodayView(showingActiveWorkout: .constant(false))
        }
    }
}

/// Builds the celebratory post-session summary from the most recent seeded
/// session, so the activation-map hero can be captured without finishing a
/// live workout.
@MainActor
private struct MuscleMapSummaryHost: View {
    let context: ModelContext
    @State private var summary: WorkoutSummary?

    var body: some View {
        Group {
            if let summary {
                WorkoutSummaryView(summary: summary, showsDismiss: false)
            } else {
                Color.clear
            }
        }
        .task {
            var descriptor = FetchDescriptor<Workout>(
                predicate: #Predicate { $0.endedAt != nil },
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            descriptor.fetchLimit = 12
            let finished = (try? context.fetch(descriptor)) ?? []
            guard let recent = finished.first else { return }
            let records = WorkoutMetrics.detectPersonalRecords(
                for: recent, history: Array(finished.dropFirst())
            )
            summary = WorkoutSummary(workout: recent, personalRecords: records)
        }
    }
}

// MARK: - Demo data

@MainActor
private enum DemoData {

    static func makeContainer(includeInProgress: Bool) -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Workout.self, Exercise.self, WorkoutTemplate.self,
            configurations: config
        )
        let context = container.mainContext
        SeedData.seedIfNeeded(context)
        seedHistory(context)
        if includeInProgress { seedInProgress(context) }
        try? context.save()
        realizeRelationships(context)
        return container
    }

    /// SwiftData faults to-many inverses lazily, so a screen that reads
    /// `workout.entries` / `entry.sets` on its very first render (the @Query
    /// tabs) can briefly see empty aggregates. Touch every relationship now so
    /// the objects are already realized in the context the views will share.
    private static func realizeRelationships(_ context: ModelContext) {
        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        for workout in workouts {
            _ = workout.entries.reduce(0) { $0 + $1.sets.count }
        }
        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        for template in templates {
            _ = template.orderedItems.count
        }
    }

    /// Three weeks of progressive push/pull/legs sessions — enough for a strong
    /// readiness score, trending charts, and a muscle-diverse recent session.
    private static func seedHistory(_ context: ModelContext) {
        let byName = exercisesByName(context)
        // (daysAgo, template, [(exercise, weightKg, reps, sets)]). Most recent
        // first; the day-1 leg session lights the whole lower body on the map.
        let plan: [(Int, String, [(String, Double, Int, Int)])] = [
            (1, "Legs", [("Back Squat", 110, 5, 4), ("Romanian Deadlift", 90, 8, 3),
                         ("Leg Press", 180, 10, 3), ("Standing Calf Raise", 60, 12, 4)]),
            (3, "Push", [("Barbell Bench Press", 80, 5, 4), ("Overhead Press", 50, 6, 3),
                         ("Incline Dumbbell Press", 30, 10, 3), ("Triceps Pushdown", 25, 12, 3)]),
            (5, "Pull", [("Deadlift", 140, 5, 3), ("Pull-Up", 0, 8, 3),
                         ("Bent-Over Row", 70, 8, 3), ("Barbell Curl", 30, 10, 3)]),
            (8, "Legs", [("Back Squat", 107.5, 5, 4), ("Romanian Deadlift", 87.5, 8, 3),
                         ("Leg Press", 175, 10, 3)]),
            (10, "Push", [("Barbell Bench Press", 77.5, 5, 4), ("Overhead Press", 47.5, 6, 3),
                          ("Triceps Pushdown", 22.5, 12, 3)]),
            (12, "Pull", [("Deadlift", 135, 5, 3), ("Bent-Over Row", 67.5, 8, 3),
                          ("Barbell Curl", 27.5, 10, 3)]),
            (15, "Legs", [("Back Squat", 105, 5, 4), ("Leg Press", 170, 10, 3)]),
        ]
        let calendar = Calendar.current
        for (daysAgo, template, items) in plan {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
            let workout = Workout(
                startedAt: date,
                endedAt: date.addingTimeInterval(60 * 58),
                energy: .good,
                templateName: template
            )
            context.insert(workout)
            for (order, item) in items.enumerated() {
                guard let exercise = byName[item.0] else { continue }
                let entry = ExerciseEntry(order: order, exercise: exercise)
                entry.workout = workout
                context.insert(entry)
                for setIndex in 0..<item.3 {
                    let set = SetEntry(
                        order: setIndex,
                        weightKilograms: item.1,
                        reps: item.2,
                        isCompleted: true
                    )
                    set.entry = entry
                    context.insert(set)
                }
            }
        }
    }

    /// A half-finished push session for the active-logging screen.
    private static func seedInProgress(_ context: ModelContext) {
        let byName = exercisesByName(context)
        let workout = Workout(templateName: "Push")
        context.insert(workout)
        let plan: [(String, Double, Int, [Bool])] = [
            ("Barbell Bench Press", 80, 5, [true, true, false, false]),
            ("Overhead Press", 50, 6, [false, false, false]),
        ]
        for (order, item) in plan.enumerated() {
            guard let exercise = byName[item.0] else { continue }
            let entry = ExerciseEntry(order: order, exercise: exercise)
            entry.workout = workout
            context.insert(entry)
            for (setIndex, done) in item.3.enumerated() {
                let set = SetEntry(order: setIndex, weightKilograms: item.1, reps: item.2, isCompleted: done)
                set.entry = entry
                context.insert(set)
            }
        }
    }

    private static func exercisesByName(_ context: ModelContext) -> [String: Exercise] {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
    }
}
#endif
