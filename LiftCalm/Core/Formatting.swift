//
//  Formatting.swift
//  LiftCalm
//
//  Display helpers for weights, volume, and durations. All inputs are canonical
//  kilograms; conversion to the user's unit happens here at the UI boundary.
//

import Foundation

enum Formatting {

    /// Formats a canonical kg value into the user's unit, e.g. "60 kg" or "135 lb".
    /// Drops the fractional part when it rounds cleanly to keep logs scannable.
    static func weight(_ kilograms: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kilograms)
        return "\(number(value)) \(unit.abbreviation)"
    }

    /// Just the numeric weight in the user's unit, no unit suffix (for fields).
    static func weightValue(_ kilograms: Double, unit: WeightUnit) -> String {
        number(unit.fromKilograms(kilograms))
    }

    /// Volume load, shown in the user's unit. Large numbers get a thousands
    /// separator; the unit suffix is included.
    static func volume(_ kilograms: Double, unit: WeightUnit) -> String {
        let value = unit.fromKilograms(kilograms)
        let formatted = value.formatted(.number.precision(.fractionLength(0)))
        return "\(formatted) \(unit.abbreviation)"
    }

    /// Human duration like "1h 12m" or "48m".
    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    /// Countdown like "1:05" for the rest timer.
    static func clock(_ seconds: Int) -> String {
        let safe = max(0, seconds)
        return String(format: "%d:%02d", safe / 60, safe % 60)
    }

    /// Rounds to at most one decimal and trims a trailing ".0".
    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }
}
