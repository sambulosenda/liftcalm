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
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Local store by default; iCloud (CloudKit) when the user enabled sync and
        // Plus is unlocked. Falls back to local if the cloud store can't be created.
        modelContainer = PersistenceController.makeContainer()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let screen = ScreenshotHarness.requestedScreen {
                // App Store screenshot mode (launch arg only) — seeds demo data
                // and renders one screen. Never reached in normal use or Release.
                ScreenshotRootView(screen: screen)
            } else {
                productionRoot
            }
            #else
            productionRoot
            #endif
        }
    }

    private var productionRoot: some View {
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
                    // Publish the first Home Screen widget snapshot now that data and
                    // the entitlement are settled.
                    WidgetBridge.refresh(context: context)
                }
                // Keep the widget current: when Plus unlocks/locks, and whenever we
                // return to the foreground (covers finishes, time drift, edits).
                .onChange(of: store.isPlus) {
                    WidgetBridge.refresh(context: modelContainer.mainContext)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        WidgetBridge.refresh(context: modelContainer.mainContext)
                    }
                }
                .modelContainer(modelContainer)
    }
}
