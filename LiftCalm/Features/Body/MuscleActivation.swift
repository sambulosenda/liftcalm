//
//  MuscleActivation.swift
//  LiftCalm
//
//  Bridges LiftCalm's coarse `MuscleGroup` taxonomy onto the MuscleMap SDK's
//  finer `Muscle` set, and turns an effective-sets-per-muscle distribution
//  (see `Workout.muscleSets()`) into the `[MuscleIntensity]` the body map
//  renders. Kept free of view code so the translation is easy to reason about.
//

import SwiftUI
import MuscleMap

enum MuscleActivation {

    /// Any trained muscle lights to at least this intensity, so a muscle you
    /// worked stays visible even when another muscle dominates the session.
    static let minVisibleIntensity: Double = 0.28

    /// Anatomical translation: one LiftCalm group → the SDK muscles that stand
    /// in for it. `.other` has no body home (empty); `.fullBody` spreads across
    /// the major movers so whole-body lifts read across the whole figure.
    static func muscles(for group: MuscleGroup) -> [Muscle] {
        switch group {
        case .chest:      [.chest]
        case .back:       [.upperBack, .lowerBack]
        case .shoulders:  [.deltoids]
        case .biceps:     [.biceps]
        case .triceps:    [.triceps]
        case .quads:      [.quadriceps]
        case .hamstrings: [.hamstring]
        case .glutes:     [.gluteal]
        case .calves:     [.calves]
        case .core:       [.abs, .obliques]
        case .fullBody:   [.chest, .upperBack, .quadriceps, .gluteal, .hamstring, .abs, .deltoids]
        case .other:      []
        }
    }

    /// Builds heatmap intensities from effective sets per muscle. Normalizes
    /// against the hardest-worked muscle so the session's relative emphasis
    /// reads at a glance, with a floor (`minVisibleIntensity`) so any trained
    /// muscle stays visible. Groups that map onto the same SDK muscle merge by
    /// the strongest signal, so nothing exceeds full intensity. `[]` for an
    /// empty distribution.
    static func intensities(from setsByGroup: [MuscleGroup: Double]) -> [MuscleIntensity] {
        let maxSets = setsByGroup.values.max() ?? 0
        guard maxSets > 0 else { return [] }

        var byMuscle: [Muscle: Double] = [:]
        for (group, sets) in setsByGroup where sets > 0 {
            let normalized = sets / maxSets
            let intensity = minVisibleIntensity + (1 - minVisibleIntensity) * normalized
            for muscle in muscles(for: group) {
                byMuscle[muscle] = max(byMuscle[muscle] ?? 0, intensity)
            }
        }
        return byMuscle.map { MuscleIntensity(muscle: $0.key, intensity: $0.value) }
    }
}

extension BodyModel {
    /// The SDK gender for this display preference.
    var sdkGender: BodyGender { self == .feminine ? .female : .male }
}

extension BodyViewStyle {
    /// Calm body styling tuned for LiftCalm. The default SDK fill is a fixed
    /// light gray that fades on the near-white summary background, so this uses
    /// a scheme-adaptive neutral plus a hairline stroke that keeps individual
    /// muscles defined even before any heatmap color lands.
    static var liftCalm: BodyViewStyle {
        BodyViewStyle(
            defaultFillColor: Color(light: 0xB4BAC2, dark: 0xC3C8CE),
            strokeColor: Color(light: 0x9AA1AB, dark: 0x80868E),
            strokeWidth: 0.6
        )
    }
}

extension HeatmapColorScale {
    /// LiftCalm's calm activation ramp: cool blue (light work) → brand green →
    /// warm amber (hardest-worked), tuned to the app palette rather than the
    /// SDK's default red-hot `.workout` scale.
    static var liftCalm: HeatmapColorScale {
        HeatmapColorScale(colors: [Theme.calmBlue, Theme.accent, Theme.caution])
    }
}
