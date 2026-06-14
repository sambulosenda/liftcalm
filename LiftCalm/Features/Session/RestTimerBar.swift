//
//  RestTimerBar.swift
//  LiftCalm
//
//  Docked rest countdown. Ticks via TimelineView (driven by the controller's
//  absolute end date, so it stays correct across backgrounding). Haptic fires
//  when the underlying completion token advances.
//

import SwiftUI

struct RestTimerBar: View {
    @Environment(SessionController.self) private var session
    @Environment(AppSettings.self) private var settings

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let remaining = session.restSecondsRemaining(asOf: context.date)
            HStack(spacing: 14) {
                adjustButton(by: -15, symbol: "gobackward.15")

                VStack(spacing: 4) {
                    Text(Formatting.clock(remaining))
                        .font(.title2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(Theme.calmBlue)
                    ProgressView(value: progress(remaining))
                        .tint(Theme.calmBlue)
                }
                .frame(maxWidth: .infinity)

                adjustButton(by: 15, symbol: "goforward.15")

                Button("Skip") { session.stopRest() }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: Theme.controlCornerRadius)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Rest timer")
            .accessibilityValue("\(remaining) seconds remaining")
        }
        .sensoryFeedback(.success, trigger: session.restCompletionToken)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func progress(_ remaining: Int) -> Double {
        guard session.restTotalSeconds > 0 else { return 0 }
        return Double(remaining) / Double(session.restTotalSeconds)
    }

    private func adjustButton(by seconds: Int, symbol: String) -> some View {
        Button {
            session.adjustRest(by: seconds)
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(seconds < 0 ? "Subtract 15 seconds" : "Add 15 seconds")
    }
}
