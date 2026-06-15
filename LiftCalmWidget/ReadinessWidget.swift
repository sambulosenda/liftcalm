//
//  ReadinessWidget.swift
//  LiftCalmWidget
//
//  Home Screen + Lock Screen readiness glance. Reads the app's shared snapshot
//  (App Group) — no SwiftData/engine here. Readiness is a Plus perk, so a free
//  snapshot shows a gentle unlock prompt instead of the score.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct ReadinessEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct ReadinessProvider: TimelineProvider {
    func placeholder(in context: Context) -> ReadinessEntry {
        ReadinessEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ReadinessEntry) -> Void) {
        let snapshot = WidgetSnapshotStore.read() ?? (context.isPreview ? .preview : nil)
        completion(ReadinessEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ReadinessEntry>) -> Void) {
        let entry = ReadinessEntry(date: Date(), snapshot: WidgetSnapshotStore.read())
        // Nudge a refresh a few hours out so relative "last session" stays roughly
        // current even when the app isn't opened; the app reloads on real changes.
        let next = Calendar.current.date(byAdding: .hour, value: 3, to: Date())
            ?? Date().addingTimeInterval(3 * 3600)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct ReadinessWidget: Widget {
    let kind = "ReadinessWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReadinessProvider()) { entry in
            ReadinessWidgetView(entry: entry)
        }
        .configurationDisplayName("Readiness")
        .description("Your training readiness at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Root view

struct ReadinessWidgetView: View {
    let entry: ReadinessEntry

    var body: some View {
        if let snapshot = entry.snapshot {
            if snapshot.isPlus {
                UnlockedReadiness(snapshot: snapshot)
            } else {
                LockedReadiness()
            }
        } else {
            EmptyReadiness()
        }
    }
}

// MARK: - Unlocked

private struct UnlockedReadiness: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: WidgetSnapshot

    private var tint: Color { Color(light: snapshot.tintLight, dark: snapshot.tintDark) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: Double(snapshot.readinessValue), in: 0...100) {
                Text("RDY")
            } currentValueLabel: {
                Text("\(snapshot.readinessValue)")
            }
            .gaugeStyle(.accessoryCircular)
            .containerBackground(.clear, for: .widget)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Readiness \(snapshot.readinessValue)").font(.headline)
                Text(snapshot.bandLabel).font(.caption)
                Text(snapshot.suggestion).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .containerBackground(.clear, for: .widget)

        case .systemMedium:
            HStack(spacing: 16) {
                ReadinessRing(value: snapshot.readinessValue, tint: tint, diameter: 86, lineWidth: 9)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.bandLabel).font(.headline).foregroundStyle(tint)
                    Text(snapshot.suggestion)
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    Spacer(minLength: 0)
                    HStack(spacing: 12) {
                        Label(WidgetFormat.lastShort(snapshot), systemImage: "clock.arrow.circlepath")
                        Label("\(snapshot.weekSetCount) sets", systemImage: "checkmark")
                    }
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { gradient }

        default: // systemSmall
            VStack(alignment: .leading, spacing: 8) {
                ReadinessRing(value: snapshot.readinessValue, tint: tint, diameter: 62, lineWidth: 8)
                Text(snapshot.bandLabel).font(.headline).foregroundStyle(tint).lineLimit(1)
                Spacer(minLength: 0)
                Text(WidgetFormat.lastLine(snapshot))
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .containerBackground(for: .widget) { gradient }
        }
    }

    private var gradient: some View {
        LinearGradient(colors: [tint.opacity(0.16), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Locked (no Plus)

private struct LockedReadiness: View {
    @Environment(\.widgetFamily) private var family
    private let tint = Color(light: 0x277552, dark: 0x5CB897)

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "lock.fill").font(.title3)
                .containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            Label("LiftCalm Plus", systemImage: "lock.fill").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(.clear, for: .widget)
        default:
            VStack(spacing: 6) {
                Image(systemName: "lock.fill").font(.title2).foregroundStyle(tint)
                Text("LiftCalm Plus").font(.headline)
                Text("Unlock readiness on your Home Screen.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .containerBackground(for: .widget) {
                LinearGradient(colors: [tint.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

// MARK: - Empty (no snapshot yet)

private struct EmptyReadiness: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            Image(systemName: "dumbbell.fill").containerBackground(.clear, for: .widget)
        case .accessoryRectangular:
            Text("Open LiftCalm").font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .containerBackground(.clear, for: .widget)
        default:
            VStack(spacing: 6) {
                Image(systemName: "dumbbell.fill").font(.title2).foregroundStyle(.secondary)
                Text("Open LiftCalm").font(.subheadline.weight(.medium))
                Text("Open the app to sync your readiness.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .containerBackground(for: .widget) { Color(.systemBackground) }
        }
    }
}

// MARK: - Shared pieces

private struct ReadinessRing: View {
    let value: Int
    let tint: Color
    var diameter: CGFloat = 62
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat(value) / 100)
                .stroke(tint.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(value)")
                .font(.system(size: diameter * 0.34, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: diameter, height: diameter)
    }
}

enum WidgetFormat {
    static func lastLine(_ snapshot: WidgetSnapshot) -> String {
        guard let last = snapshot.lastWorkoutAt else { return "No sessions yet" }
        return "Last \(relative(last)) · \(snapshot.weekSetCount) sets/wk"
    }

    static func lastShort(_ snapshot: WidgetSnapshot) -> String {
        guard let last = snapshot.lastWorkoutAt else { return "—" }
        return relative(last)
    }

    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Light/dark dynamic color from baked hex (widget-local copy of the app helper).
private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry(date: .now, snapshot: .preview)
    ReadinessEntry(date: .now, snapshot: .previewLocked)
    ReadinessEntry(date: .now, snapshot: nil)
}

#Preview("Medium", as: .systemMedium) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry(date: .now, snapshot: .preview)
    ReadinessEntry(date: .now, snapshot: .previewLocked)
}

#Preview("Circular", as: .accessoryCircular) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry(date: .now, snapshot: .preview)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    ReadinessWidget()
} timeline: {
    ReadinessEntry(date: .now, snapshot: .preview)
}
