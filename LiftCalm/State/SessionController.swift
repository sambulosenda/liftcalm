//
//  SessionController.swift
//  LiftCalm
//
//  Owns the in-progress workout and the rest timer. Held at app scope so an
//  active session survives tab switches and the bottom "now training" accessory
//  can surface it from anywhere.
//
//  Mutations go through here (not scattered across views) so logging stays fast,
//  consistent, and easy to reason about. SwiftData inserts/deletes use the
//  ModelContext registered once at app start.
//

import SwiftUI
import SwiftData

@Observable
@MainActor
final class SessionController {

    /// The session currently being logged, if any.
    private(set) var activeWorkout: Workout?

    var isWorkoutActive: Bool { activeWorkout != nil }

    // MARK: Rest timer
    /// Absolute time the current rest ends. Absolute (not a countdown int) so it
    /// stays correct across backgrounding and view re-renders.
    private(set) var restEndDate: Date?
    /// Total duration of the active rest, for progress rendering.
    private(set) var restTotalSeconds: Int = 0
    /// Bumped when a rest completes — views observe this to fire a haptic.
    private(set) var restCompletionToken: Int = 0

    var isResting: Bool { restEndDate != nil }

    /// Seconds left, never negative. Read inside a TimelineView for live ticking.
    func restSecondsRemaining(asOf now: Date) -> Int {
        guard let restEndDate else { return 0 }
        return max(0, Int(restEndDate.timeIntervalSince(now).rounded(.up)))
    }

    // MARK: - Dependencies

    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var settings: AppSettings?
    @ObservationIgnored private var restTimer: Timer?

    /// Called once at app launch to wire up persistence and preferences, then
    /// resume any session left unfinished (e.g. the app was killed mid-workout).
    func configure(context: ModelContext, settings: AppSettings) {
        self.context = context
        self.settings = settings
        resumeUnfinishedWorkout()
    }

    /// Adopts an existing workout as the active session. Used to resume after a
    /// relaunch and by previews.
    func resume(_ workout: Workout) {
        activeWorkout = workout
    }

    private func resumeUnfinishedWorkout() {
        guard activeWorkout == nil, let context else { return }
        var descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt == nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        activeWorkout = try? context.fetch(descriptor).first
    }

    // MARK: - Session lifecycle

    /// Starts an empty session.
    @discardableResult
    func startEmptyWorkout() -> Workout {
        let workout = Workout()
        insert(workout)
        activeWorkout = workout
        return workout
    }

    /// Starts a session pre-filled from a template: one entry per item, each
    /// seeded with the template's target number of (incomplete) working sets.
    @discardableResult
    func startWorkout(from template: WorkoutTemplate) -> Workout {
        let workout = Workout(templateName: template.name)
        insert(workout)
        for (index, item) in template.orderedItems.enumerated() {
            guard let exercise = item.exercise else { continue }
            let entry = ExerciseEntry(order: index, exercise: exercise)
            entry.workout = workout
            insert(entry)
            for setIndex in 0..<max(1, item.targetSets) {
                let set = SetEntry(order: setIndex)
                set.entry = entry
                insert(set)
            }
        }
        activeWorkout = workout
        return workout
    }

    /// Marks the session finished and clears it from active state.
    func finishWorkout() {
        stopRest()
        activeWorkout?.endedAt = Date()
        save()
        activeWorkout = nil
    }

    /// Deletes the in-progress session entirely (user discarded it).
    func discardWorkout() {
        stopRest()
        if let workout = activeWorkout {
            context?.delete(workout)
            save()
        }
        activeWorkout = nil
    }

    // MARK: - Entry & set editing

    @discardableResult
    func addExercise(_ exercise: Exercise, to workout: Workout) -> ExerciseEntry {
        let order = (workout.entries.map(\.order).max() ?? -1) + 1
        let entry = ExerciseEntry(order: order, exercise: exercise)
        entry.workout = workout
        insert(entry)
        // Start with one empty set so the user can log immediately.
        addSet(to: entry)
        save()
        return entry
    }

    func removeEntry(_ entry: ExerciseEntry) {
        context?.delete(entry)
        save()
    }

    /// Adds a set, copying weight/reps from the previous set as a fast default.
    @discardableResult
    func addSet(to entry: ExerciseEntry) -> SetEntry {
        let previous = entry.orderedSets.last
        let order = (entry.sets.map(\.order).max() ?? -1) + 1
        let set = SetEntry(
            order: order,
            weightKilograms: previous?.weightKilograms ?? 0,
            reps: previous?.reps ?? 0
        )
        set.entry = entry
        insert(set)
        save()
        return set
    }

    func removeSet(_ set: SetEntry) {
        context?.delete(set)
        save()
    }

    /// Toggles completion. On completing a qualifying set, optionally kicks off
    /// the rest timer per user preference.
    func toggleCompletion(_ set: SetEntry) {
        set.isCompleted.toggle()
        save()
        if set.isCompleted, settings?.autoStartRest == true {
            startRest()
        }
    }

    // MARK: - Rest timer

    /// Starts (or restarts) rest using the user's default duration unless one is
    /// supplied. Schedules a one-shot timer to flag completion for haptics.
    func startRest(seconds: Int? = nil) {
        let duration = max(1, seconds ?? settings?.defaultRestSeconds ?? 90)
        restTotalSeconds = duration
        restEndDate = Date().addingTimeInterval(TimeInterval(duration))
        scheduleCompletionTimer(after: TimeInterval(duration))
    }

    /// Adds (or removes, with a negative value) time from the running rest.
    func adjustRest(by deltaSeconds: Int) {
        guard let current = restEndDate else { return }
        let newEnd = current.addingTimeInterval(TimeInterval(deltaSeconds))
        // Don't let an adjustment end rest in the past.
        restEndDate = max(newEnd, Date().addingTimeInterval(1))
        restTotalSeconds = max(1, restTotalSeconds + deltaSeconds)
        scheduleCompletionTimer(after: restEndDate!.timeIntervalSinceNow)
    }

    func stopRest() {
        restTimer?.invalidate()
        restTimer = nil
        restEndDate = nil
        restTotalSeconds = 0
    }

    /// Re-evaluate after returning from the background — the scheduled timer may
    /// not have fired while suspended.
    func refreshRestState() {
        guard let restEndDate else { return }
        if restEndDate.timeIntervalSinceNow <= 0 {
            completeRest()
        }
    }

    private func scheduleCompletionTimer(after interval: TimeInterval) {
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: max(0.1, interval), repeats: false) { [weak self] _ in
            Task { @MainActor in self?.completeRest() }
        }
    }

    private func completeRest() {
        stopRest()
        restCompletionToken &+= 1
    }

    // MARK: - Persistence helpers

    private func insert(_ model: some PersistentModel) {
        context?.insert(model)
    }

    private func save() {
        try? context?.save()
    }
}
