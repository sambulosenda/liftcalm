//
//  WidgetBridge.swift
//  LiftCalm
//
//  Publishes a small readiness snapshot to the shared App Group container and
//  asks WidgetKit to reload. Cheap and idempotent — safe to call on launch, on
//  returning to the foreground, after a finished session, and when Plus flips.
//

import Foundation
import SwiftData
import WidgetKit

@MainActor
enum WidgetBridge {
    /// Recomputes the snapshot from current data and refreshes all timelines.
    static func refresh(context: ModelContext) {
        WidgetSnapshotStore.write(makeSnapshot(context: context))
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func makeSnapshot(context: ModelContext) -> WidgetSnapshot {
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { $0.endedAt != nil },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        let finished = (try? context.fetch(descriptor)) ?? []
        let now = Date()
        let score = ReadinessEngine.compute(load: TrainingLoad.from(workouts: finished, now: now))
        let tint = bandHex(score.band)

        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let weekSets = finished
            .filter { $0.startedAt >= weekStart }
            .reduce(0) { $0 + $1.completedSetCount }

        return WidgetSnapshot(
            isPlus: UserDefaults.standard.bool(forKey: StoreManager.cacheKey),
            readinessValue: score.value,
            bandLabel: score.band.label,
            bandSymbol: score.band.symbol,
            suggestion: score.suggestion,
            tintLight: tint.light,
            tintDark: tint.dark,
            lastWorkoutAt: finished.first?.startedAt,
            weekSetCount: weekSets,
            generatedAt: now
        )
    }

    /// Band → brand hex pair, mirroring `ReadinessBand.tint` over Theme tokens.
    private static func bandHex(_ band: ReadinessBand) -> (light: UInt32, dark: UInt32) {
        switch band {
        case .recover: Theme.Hex.caution
        case .steady: Theme.Hex.calmBlue
        case .ready: Theme.Hex.accent
        case .primed: Theme.Hex.success
        }
    }
}
