//
//  PersistenceController.swift
//  LiftCalm
//
//  Builds the app's ModelContainer. Local-first by default; switches to an
//  iCloud (CloudKit) store only when the user has enabled sync AND Plus is
//  unlocked. If the cloud store can't be created (no iCloud account, missing
//  container, or unavailable entitlement), it falls back to local rather than
//  crashing — sync simply stays off until the environment is ready.
//
//  The choice is made once at launch (the store configuration is fixed for the
//  process), so toggling sync in Settings takes effect on the next launch.
//

import Foundation
import SwiftData

enum PersistenceController {

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Workout.self, Exercise.self, WorkoutTemplate.self])

        if shouldUseCloud {
            let cloud = ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)
            if let container = try? ModelContainer(for: schema, configurations: cloud) {
                return container
            }
            // Cloud unavailable — fall through to the local store.
        }

        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    /// Sync is opt-in and Plus-only. Both flags are read straight from
    /// UserDefaults so this stays free of @MainActor isolation at launch.
    private static var shouldUseCloud: Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: AppSettings.iCloudSyncKey)
            && defaults.bool(forKey: StoreManager.cacheKey)
    }
}
