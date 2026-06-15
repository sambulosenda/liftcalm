//
//  WidgetSnapshot.swift
//  LiftCalmWidget
//
//  KEEP IN SYNC with the byte-identical copy at LiftCalm/Core/WidgetSnapshot.swift.
//  Each target compiles its own copy (no shared framework, by design). Primitives
//  only — readiness colors are baked in as hex so this target needs zero app code.
//

import Foundation

struct WidgetSnapshot: Codable, Equatable {
    var isPlus: Bool
    var readinessValue: Int
    var bandLabel: String
    var bandSymbol: String
    var suggestion: String
    /// Band tint as resolved brand hex (light/dark), `0xRRGGBB`.
    var tintLight: UInt32
    var tintDark: UInt32
    var lastWorkoutAt: Date?
    var weekSetCount: Int
    var generatedAt: Date

    static let appGroupID = "group.com.sambulosendas1.LiftCalm"
    static let defaultsKey = "widget.snapshot.v1"
}

/// Reads/writes the snapshot in the shared App Group container.
enum WidgetSnapshotStore {
    private static var defaults: UserDefaults? { UserDefaults(suiteName: WidgetSnapshot.appGroupID) }

    static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: WidgetSnapshot.defaultsKey)
    }

    static func read() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: WidgetSnapshot.defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

extension WidgetSnapshot {
    /// Sample for the widget gallery placeholder and previews.
    static let preview = WidgetSnapshot(
        isPlus: true,
        readinessValue: 72,
        bandLabel: "Ready",
        bandSymbol: "checkmark.circle.fill",
        suggestion: "Good to train. Push your main lifts.",
        tintLight: 0x277552, tintDark: 0x5CB897,
        lastWorkoutAt: Date(timeIntervalSinceNow: -2 * 86_400),
        weekSetCount: 24,
        generatedAt: Date()
    )

    static let previewLocked = WidgetSnapshot(
        isPlus: false,
        readinessValue: 0, bandLabel: "", bandSymbol: "lock.fill", suggestion: "",
        tintLight: 0x277552, tintDark: 0x5CB897,
        lastWorkoutAt: nil, weekSetCount: 0, generatedAt: Date()
    )
}
