//
//  AppSettings.swift
//  LiftCalm
//
//  User preferences shared across the app via the environment. Backed by
//  UserDefaults but exposed as plain @Observable properties so SwiftUI tracks
//  them through the Observation framework (unlike @AppStorage inside a class,
//  which doesn't subscribe views). Each setter persists on write.
//

import SwiftUI

@Observable
@MainActor
final class AppSettings {

    /// UserDefaults key for the iCloud-sync preference. Shared with
    /// `PersistenceController`, which reads it at launch to configure the store.
    static let iCloudSyncKey = "settings.iCloudSyncEnabled"

    var weightUnit: WeightUnit { didSet { store(weightUnit.rawValue, .weightUnit) } }
    var experienceLevel: ExperienceLevel { didSet { store(experienceLevel.rawValue, .experience) } }
    var goal: TrainingGoal { didSet { store(goal.rawValue, .goal); syncRestToGoal() } }
    /// Default rest, seconds. Initialised from the goal but user-adjustable.
    var defaultRestSeconds: Int { didSet { store(defaultRestSeconds, .rest) } }
    /// Auto-start the rest timer when a working set is completed.
    var autoStartRest: Bool { didSet { store(autoStartRest, .autoRest) } }
    /// Fire a haptic when rest completes.
    var restHaptics: Bool { didSet { store(restHaptics, .haptics) } }
    /// Post a local notification when rest finishes (so it alerts while backgrounded).
    var restNotifications: Bool { didSet { store(restNotifications, .restNotify) } }
    /// Optional gentle daily training reminder.
    var workoutReminderEnabled: Bool { didSet { store(workoutReminderEnabled, .reminderOn) } }
    var reminderHour: Int { didSet { store(reminderHour, .reminderHour) } }
    var reminderMinute: Int { didSet { store(reminderMinute, .reminderMinute) } }
    var hasCompletedOnboarding: Bool { didSet { store(hasCompletedOnboarding, .onboarded) } }
    /// iCloud (CloudKit) sync of the workout store. A Plus feature; applied at the
    /// next launch, since the store configuration is fixed at startup.
    var iCloudSyncEnabled: Bool { didSet { defaults.set(iCloudSyncEnabled, forKey: Self.iCloudSyncKey) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        weightUnit = defaults.string(forKey: Key.weightUnit.rawValue)
            .flatMap(WeightUnit.init(rawValue:)) ?? .kilograms
        experienceLevel = defaults.string(forKey: Key.experience.rawValue)
            .flatMap(ExperienceLevel.init(rawValue:)) ?? .beginner
        let storedGoal = defaults.string(forKey: Key.goal.rawValue)
            .flatMap(TrainingGoal.init(rawValue:)) ?? .general
        goal = storedGoal
        defaultRestSeconds = defaults.object(forKey: Key.rest.rawValue) as? Int
            ?? storedGoal.defaultRestSeconds
        autoStartRest = defaults.object(forKey: Key.autoRest.rawValue) as? Bool ?? true
        restHaptics = defaults.object(forKey: Key.haptics.rawValue) as? Bool ?? true
        restNotifications = defaults.object(forKey: Key.restNotify.rawValue) as? Bool ?? true
        workoutReminderEnabled = defaults.object(forKey: Key.reminderOn.rawValue) as? Bool ?? false
        reminderHour = defaults.object(forKey: Key.reminderHour.rawValue) as? Int ?? 18
        reminderMinute = defaults.object(forKey: Key.reminderMinute.rawValue) as? Int ?? 0
        hasCompletedOnboarding = defaults.bool(forKey: Key.onboarded.rawValue)
        iCloudSyncEnabled = defaults.object(forKey: Self.iCloudSyncKey) as? Bool ?? false
    }

    // MARK: - Persistence

    @ObservationIgnored private let defaults: UserDefaults

    private enum Key: String {
        case weightUnit, experience, goal, rest, autoRest, haptics, onboarded
        case restNotify, reminderOn, reminderHour, reminderMinute
    }

    private func store(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    /// When the goal changes we nudge the default rest to match, but only if the
    /// user hadn't customised it away from the previous goal's default.
    private func syncRestToGoal() {
        let goalDefaults = Set(TrainingGoal.allCases.map(\.defaultRestSeconds))
        if goalDefaults.contains(defaultRestSeconds) {
            defaultRestSeconds = goal.defaultRestSeconds
        }
    }
}
