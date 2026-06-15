//
//  LiftCalmApp.swift
//  LiftCalm
//
//  Created by Sambulo Senda on 14/06/2026.
//

import SwiftUI
import SwiftData

@main
struct LiftCalmApp: App {
    /// Single source of truth for the local store. Local-first by design — no
    /// account, no network. iCloud sync is a future premium toggle.
    let modelContainer: ModelContainer
    @State private var settings = AppSettings()
    @State private var session = SessionController()
    @State private var notifications = NotificationManager()
    @State private var store = StoreManager()

    init() {
        do {
            modelContainer = try ModelContainer(
                for: Workout.self, Exercise.self, WorkoutTemplate.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(settings)
                .environment(session)
                .environment(notifications)
                .environment(store)
                .tint(Theme.accent)
                .task {
                    // Seed built-ins once and wire the session to persistence.
                    let context = modelContainer.mainContext
                    SeedData.seedIfNeeded(context)
                    session.configure(context: context, settings: settings, notifications: notifications)
                    await notifications.refreshStatus()
                    // Load the Plus product, reconcile the entitlement, and begin
                    // listening for transaction updates.
                    await store.start()
                }
        }
        .modelContainer(modelContainer)
    }
}
