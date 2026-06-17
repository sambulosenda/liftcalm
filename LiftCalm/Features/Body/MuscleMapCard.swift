//
//  MuscleMapCard.swift
//  LiftCalm
//
//  A calm front + back body map shading the muscles a set of sessions trained.
//  Pure presentation: hand it an effective-sets-per-muscle distribution (e.g.
//  `Workout.muscleSets()` for one session, or `[Workout].muscleSets()` for a
//  week). Named `MuscleMapCard` rather than `MuscleMapView` to avoid shadowing
//  the SDK's `MuscleMapView`.
//

import SwiftUI
import MuscleMap

struct MuscleMapCard: View {
    let setsByGroup: [MuscleGroup: Double]
    var title: LocalizedStringKey = "Muscles worked"
    /// Which silhouette to draw — a pure display preference (see `BodyModel`).
    var model: BodyModel = .masculine

    private var intensities: [MuscleIntensity] {
        MuscleActivation.intensities(from: setsByGroup)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: Theme.Spacing.lg) {
                figure(.front, label: "Front")
                figure(.back, label: "Back")
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
        }
        .padding(Theme.Spacing.lg)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private func figure(_ side: BodySide, label: LocalizedStringKey) -> some View {
        VStack(spacing: Theme.Spacing.xs) {
            BodyView(gender: model.sdkGender, side: side, style: .liftCalm)
                .heatmap(intensities, colorScale: .liftCalm)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    /// Spoken summary: the muscles worked, hardest first, by name.
    private var accessibilityLabel: Text {
        let worked = setsByGroup
            .filter { $0.key != .other && $0.value > 0 }
            .sorted { $0.value > $1.value }
            .map(\.key.displayName)
        guard !worked.isEmpty else { return Text("No muscles worked yet") }
        return Text("Muscles worked: \(ListFormatter.localizedString(byJoining: worked))")
    }
}

#Preview("Leg day") {
    MuscleMapCard(setsByGroup: [
        .quads: 7, .glutes: 4.5, .hamstrings: 4, .core: 3, .calves: 4, .back: 1.5
    ])
    .padding()
}

#Preview("Push day") {
    MuscleMapCard(setsByGroup: [
        .chest: 7, .shoulders: 5, .triceps: 5.5
    ])
    .padding()
}
