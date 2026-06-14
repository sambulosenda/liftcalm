//
//  ReadinessViews.swift
//  LiftCalm
//
//  Readiness glance (Today) and the recovery detail screen. The score itself is
//  computed by the pure ReadinessEngine; these views just present it calmly.
//

import SwiftUI

extension ReadinessBand {
    var tint: Color {
        switch self {
        case .recover: Theme.caution
        case .steady: Theme.calmBlue
        case .ready: Theme.accent
        case .primed: Theme.success
        }
    }
}

/// Circular readiness gauge.
struct ReadinessRing: View {
    let value: Int
    let band: ReadinessBand
    var diameter: CGFloat = 64
    var lineWidth: CGFloat = 7

    var body: some View {
        ZStack {
            Circle()
                .stroke(band.tint.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(value) / 100)
                .stroke(band.tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
        .animation(.smooth, value: value)
        .accessibilityHidden(true)
    }
}

/// Compact Today glance; taps through to the recovery detail.
struct ReadinessCard: View {
    let score: ReadinessScore

    var body: some View {
        NavigationLink {
            RecoveryView(score: score)
        } label: {
            HStack(spacing: 16) {
                ReadinessRing(value: score.value, band: score.band)
                VStack(alignment: .leading, spacing: 3) {
                    Text(score.band.label)
                        .font(.headline)
                        .foregroundStyle(score.band.tint)
                    Text(score.suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Readiness \(score.value) of 100, \(score.band.label)")
        .accessibilityHint(score.suggestion)
    }
}

/// Full recovery breakdown: score, contributing factors, and gentle guidance.
struct RecoveryView: View {
    let score: ReadinessScore

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                factorsCard
                if score.isTrainingOnly {
                    enrichmentNote
                }
                disclaimer
            }
            .padding(20)
        }
        .navigationTitle("Readiness")
        .navigationBarTitleDisplayMode(.inline)
        .background(
            LinearGradient(colors: [score.band.tint.opacity(0.08), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(spacing: 14) {
            ReadinessRing(value: score.value, band: score.band, diameter: 132, lineWidth: 12)
            Label(score.band.label, systemImage: score.band.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(score.band.tint)
            Text(score.suggestion)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Readiness \(score.value) of 100, \(score.band.label). \(score.suggestion)")
    }

    private var factorsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(score.components.enumerated()), id: \.element.id) { index, component in
                if index > 0 { Divider().padding(.leading, 16) }
                FactorRow(component: component)
            }
        }
        .padding(.vertical, 4)
        .glassCard()
    }

    private var enrichmentNote: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.text.square")
                .font(.title2)
                .foregroundStyle(Theme.calmBlue)
                .accessibilityHidden(true)
            Text("Based on your training. Sleep and heart signals from Apple Health will enhance this when available.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var disclaimer: some View {
        Label("LiftCalm is not medical advice.", systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.tertiary)
    }
}

private struct FactorRow: View {
    let component: ReadinessComponent

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(component.label)
                    .font(.subheadline.weight(.medium))
                Text(component.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(component.score)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(ReadinessBand(score: component.score).tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(component.label), \(component.detail), \(component.score) of 100")
    }
}

#Preview("Card") {
    NavigationStack {
        ScrollView {
            ReadinessCard(score: ReadinessEngine.compute(
                load: TrainingLoad(hoursSinceLastSession: 20, setsLast7Days: 30, avgDailySetsLast28Days: 4)
            ))
            .padding()
        }
    }
}

#Preview("Detail") {
    NavigationStack {
        RecoveryView(score: ReadinessEngine.compute(
            load: TrainingLoad(hoursSinceLastSession: 6, setsLast7Days: 60, avgDailySetsLast28Days: 4)
        ))
    }
}
