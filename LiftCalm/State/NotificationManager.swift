//
//  NotificationManager.swift
//  LiftCalm
//
//  Local notifications only — no push, no server, no account (privacy-first).
//  Two jobs: alert when a rest timer finishes while the app is backgrounded
//  (the rest Task is suspended in the background, so without this the user gets
//  nothing until they reopen), and an optional gentle daily training reminder.
//

import Foundation
import UserNotifications

@Observable
@MainActor
final class NotificationManager {

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    private enum ID {
        static let rest = "rest.complete"
        static let reminder = "workout.reminder"
    }

    /// Reads the current system authorization state.
    func refreshStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Requests alert/sound permission. Returns whether it's usable afterward.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshStatus()
        return granted
    }

    // MARK: - Rest timer

    /// Schedules the rest-complete alert. No-op if the end time has passed.
    /// Requests permission lazily the first time, so the timer "just works".
    func scheduleRestComplete(at date: Date) {
        let interval = date.timeIntervalSinceNow
        guard interval > 0 else { return }
        Task {
            guard await ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest complete"
            content.body = "Time for your next set."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: ID.rest, content: content, trigger: trigger))
        }
    }

    func cancelRestComplete() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.rest])
        center.removeDeliveredNotifications(withIdentifiers: [ID.rest])
    }

    // MARK: - Daily reminder

    /// Schedules a repeating gentle reminder at the given local time.
    func scheduleDailyReminder(hour: Int, minute: Int) {
        Task {
            guard await ensureAuthorized() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Time to train?"
            content.body = "A few focused sets is all it takes."
            content.sound = .default
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: ID.reminder, content: content, trigger: trigger))
        }
    }

    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [ID.reminder])
    }

    // MARK: - Helpers

    private func ensureAuthorized() async -> Bool {
        await refreshStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined: return await requestAuthorization()
        default: return false
        }
    }
}
