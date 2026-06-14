//
//  SharedComponents.swift
//  LiftCalm
//
//  Small reusable building blocks and style shims used across features.
//

import SwiftUI

/// Consistent section heading with an optional subtitle.
struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String?) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// A finished-workout summary row used in Today and History.
struct WorkoutRow: View {
    let workout: Workout
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(Theme.success)
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.templateName ?? "Workout")
                    .font(.headline)
                Text(workout.startedAt, format: .dateTime.weekday().month().day())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(Formatting.volume(workout.totalVolume, unit: settings.weightUnit))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text("\(workout.completedSetCount) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Button style shim

extension PrimitiveButtonStyle where Self == GlassProminentCompatStyle {
    /// Glass-prominent on iOS 26, bordered-prominent fallback otherwise.
    static var glassProminentCompat: GlassProminentCompatStyle { .init() }
}

struct GlassProminentCompatStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            Button(configuration).buttonStyle(.glassProminent)
        } else {
            Button(configuration).buttonStyle(.borderedProminent)
        }
    }
}
