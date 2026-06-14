//
//  Readiness.swift
//  LiftCalm
//
//  Training Readiness — a transparent, rule-based recovery score. No ML, no
//  black box: it's a weighted blend of sub-scores the UI can show plainly.
//
//  Designed training-load-first so it works for everyone, including iPhone-only
//  users with no Apple Watch: training load (from our own logs) always
//  contributes, while sleep / HRV / resting-HR are *optional* signals that light
//  up when HealthKit provides them. Everything here is pure and unit-testable;
//  data sources (SwiftData, HealthKit) live behind boundaries elsewhere.
//

import Foundation

// MARK: - Inputs

/// Optional recovery signals sourced from HealthKit. All optional so the engine
/// degrades gracefully when a signal (or HealthKit itself) is unavailable.
struct RecoveryInputs: Equatable {
    var sleepHours: Double?
    /// Last night's overnight HRV (SDNN, ms) and the personal rolling baseline.
    var hrvLastNight: Double?
    var hrvBaseline: Double?
    /// Last night's resting HR and the personal rolling baseline (bpm).
    var rhrLastNight: Double?
    var rhrBaseline: Double?

    static let none = RecoveryInputs()
}

/// Training stress derived from logged sessions. Always available.
struct TrainingLoad: Equatable {
    /// Hours since the most recent finished session. `nil` when no history.
    var hoursSinceLastSession: Double?
    var setsLast7Days: Int
    /// Mean qualifying sets per day over the chronic window (last 28 days).
    var avgDailySetsLast28Days: Double

    static let fresh = TrainingLoad(
        hoursSinceLastSession: nil, setsLast7Days: 0, avgDailySetsLast28Days: 0
    )

    /// Builds load from finished workouts. `now` is injected for deterministic
    /// tests. Counts only qualifying sets (completed, non-warm-up, reps > 0).
    static func from(workouts: [Workout], now: Date) -> TrainingLoad {
        let finished = workouts.filter { $0.endedAt != nil }
        guard !finished.isEmpty else { return .fresh }

        let lastEnd = finished.compactMap(\.endedAt).max()
        let hoursSince = lastEnd.map { now.timeIntervalSince($0) / 3600 }

        func sets(sinceDaysAgo days: Double) -> Int {
            let cutoff = now.addingTimeInterval(-days * 86_400)
            return finished
                .filter { $0.startedAt >= cutoff }
                .reduce(0) { $0 + $1.completedSetCount }
        }

        return TrainingLoad(
            hoursSinceLastSession: hoursSince.map { max(0, $0) },
            setsLast7Days: sets(sinceDaysAgo: 7),
            avgDailySetsLast28Days: Double(sets(sinceDaysAgo: 28)) / 28
        )
    }
}

// MARK: - Output

enum ReadinessBand: String, Equatable {
    case recover, steady, ready, primed

    /// Threshold mapping from a 0–100 score.
    init(score: Int) {
        switch score {
        case ..<40: self = .recover
        case 40..<60: self = .steady
        case 60..<80: self = .ready
        default: self = .primed
        }
    }

    var label: String {
        switch self {
        case .recover: "Recover"
        case .steady: "Steady"
        case .ready: "Ready"
        case .primed: "Primed"
        }
    }

    var suggestion: String {
        switch self {
        case .recover: "Low readiness. Consider lighter work, mobility, or a rest day."
        case .steady: "Feeling moderate. Keep it steady — quality over volume today."
        case .ready: "You're ready. Train as planned."
        case .primed: "You're primed. A great day to push a little."
        }
    }

    var symbol: String {
        switch self {
        case .recover: "leaf.fill"
        case .steady: "figure.walk"
        case .ready: "checkmark.circle.fill"
        case .primed: "bolt.fill"
        }
    }
}

/// One contributing factor, surfaced for transparency in the detail view.
struct ReadinessComponent: Equatable, Identifiable {
    let id: String
    let label: String
    let detail: String
    let score: Int
}

struct ReadinessScore: Equatable {
    let value: Int
    let band: ReadinessBand
    let components: [ReadinessComponent]
    /// True when only training load fed the score (no HealthKit signals).
    let isTrainingOnly: Bool

    var suggestion: String { band.suggestion }
}

// MARK: - Engine

enum ReadinessEngine {

    /// Base weights; renormalized over whichever signals are present.
    private enum Weight {
        static let load = 0.45, sleep = 0.25, hrv = 0.22, rhr = 0.08
    }

    /// Computes readiness from training load plus any available recovery signals.
    static func compute(load: TrainingLoad, inputs: RecoveryInputs = .none) -> ReadinessScore {
        var weighted: [(score: Double, weight: Double)] = []
        var components: [ReadinessComponent] = []

        // Training load — always present. Two transparent factors.
        let recovery = recoveryFactor(load)
        let balance = balanceFactor(load)
        let loadScore = recovery.score * 0.6 + balance.score * 0.4
        weighted.append((loadScore, Weight.load))
        components.append(recovery.component)
        components.append(balance.component)

        // Sleep.
        if let hours = inputs.sleepHours {
            let s = sleepScore(hours)
            weighted.append((s, Weight.sleep))
            components.append(ReadinessComponent(
                id: "sleep", label: "Sleep",
                detail: String(format: "%.1f h last night", hours), score: Int(s.rounded())
            ))
        }

        // HRV — higher vs baseline = more recovered.
        if let last = inputs.hrvLastNight, let base = inputs.hrvBaseline, base > 0 {
            let s = ratioScore(last / base, good: 1.0, floor: 0.7)
            weighted.append((s, Weight.hrv))
            components.append(ReadinessComponent(
                id: "hrv", label: "HRV",
                detail: last >= base ? "Above your baseline" : "Below your baseline",
                score: Int(s.rounded())
            ))
        }

        // Resting HR — lower vs baseline = more recovered (inverse ratio).
        if let last = inputs.rhrLastNight, let base = inputs.rhrBaseline, last > 0 {
            let s = ratioScore(base / last, good: 1.0, floor: 0.8)
            weighted.append((s, Weight.rhr))
            components.append(ReadinessComponent(
                id: "rhr", label: "Resting HR",
                detail: last <= base ? "At or below baseline" : "Above baseline",
                score: Int(s.rounded())
            ))
        }

        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        let value = totalWeight > 0
            ? Int((weighted.reduce(0) { $0 + $1.score * $1.weight } / totalWeight).rounded())
            : 85
        let clamped = min(100, max(0, value))

        return ReadinessScore(
            value: clamped,
            band: ReadinessBand(score: clamped),
            components: components,
            isTrainingOnly: inputs == .none
        )
    }

    // MARK: Factors

    /// More time since the last session = more recovered, leveling off ~48h.
    /// No history → fully fresh.
    private static func recoveryFactor(_ load: TrainingLoad) -> (score: Double, component: ReadinessComponent) {
        guard let hours = load.hoursSinceLastSession else {
            return (95, ReadinessComponent(id: "recovery", label: "Recovery",
                                           detail: "No recent sessions — fresh", score: 95))
        }
        // 0h → 45, ramps to 100 by 48h.
        let score = min(100, 45 + hours / 48 * 55)
        let detail = hours < 1 ? "Just trained"
            : hours < 36 ? "Last trained \(Int(hours.rounded()))h ago"
            : "Well rested"
        return (score, ReadinessComponent(id: "recovery", label: "Recovery", detail: detail, score: Int(score.rounded())))
    }

    /// Acute (7-day avg) vs chronic (28-day avg) load. Ramping up too fast lowers
    /// readiness; balanced or tapering keeps it high.
    private static func balanceFactor(_ load: TrainingLoad) -> (score: Double, component: ReadinessComponent) {
        let acuteDaily = Double(load.setsLast7Days) / 7
        guard load.avgDailySetsLast28Days > 0 else {
            return (90, ReadinessComponent(id: "balance", label: "Training balance",
                                           detail: "Building your baseline", score: 90))
        }
        let ratio = acuteDaily / load.avgDailySetsLast28Days
        // ratio 1.0 ≈ sustainable (90); >1.0 penalized; <1.0 (tapering) stays high.
        let score = min(100, max(35, 100 - max(0, ratio - 1.0) * 110))
        let detail = ratio > 1.3 ? "Ramping up fast" : ratio < 0.8 ? "Lighter than usual" : "On track vs usual"
        return (score, ReadinessComponent(id: "balance", label: "Training balance", detail: detail, score: Int(score.rounded())))
    }

    /// Sleep hours → 0–100. Target ~8h; degrades below, mild bonus plateau above.
    private static func sleepScore(_ hours: Double) -> Double {
        switch hours {
        case ..<0: 0
        case 0..<8: max(0, hours / 8 * 100)
        default: 100
        }
    }

    /// Maps a recovery ratio (value/baseline, higher = better) to 0–100, where
    /// `good` maps to 100 and `floor` maps to ~30.
    private static func ratioScore(_ ratio: Double, good: Double, floor: Double) -> Double {
        if ratio >= good { return 100 }
        if ratio <= floor { return 30 }
        return 30 + (ratio - floor) / (good - floor) * 70
    }
}
