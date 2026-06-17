//
//  PersistenceController.swift
//  LiftCalm
//
//  Builds the app's ModelContainer. Local-only: everything stays on device.
//
//  iCloud (CloudKit) sync is deferred to a later release — it needs the iCloud
//  capability + container wired up in Xcode and device-to-device testing before
//  it can ship. Until then we never construct a CloudKit-backed store, so the
//  app can't promise sync it doesn't deliver. The models already follow
//  CloudKit's constraints (no unique, defaulted properties, inverse relations)
//  so enabling it later is purely a configuration change.
//

import Foundation
import SwiftData

enum PersistenceController {

    static func makeContainer() -> ModelContainer {
        let schema = Schema([Workout.self, Exercise.self, WorkoutTemplate.self])
        let local = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: local)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
}
