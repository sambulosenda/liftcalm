//
//  ProgressDashboardView.swift
//  LiftCalm
//
//  The Progress tab: per-exercise estimated-1RM and volume trends over time —
//  the "is it working?" view. A Plus feature, so free users see a calm,
//  clearly-labelled sample and an unlock CTA (mirroring the readiness gate);
//  Plus users get the live charts over their own history.
//
//  Named ...DashboardView (not ProgressView) to avoid shadowing SwiftUI's
//  ProgressView spinner used elsewhere in the app.
//

import SwiftUI
import SwiftData
import Charts

struct ProgressDashboardView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.presentPaywall) private var presentPaywall
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        filter: #Predicate<Workout> { $0.endedAt != nil },
        sort: \Workout.startedAt, order: .reverse
    )
    private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            Group {
                if store.isPlus {
                    PlusProgressContent(workouts: workouts)
                } else {
                    LockedProgressView { presentPaywall(.charts) }
                }
            }
            .navigationTitle("Progress")
            .background(backgroundTint)
        }
    }

    private var backgroundTint: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(colorScheme == .dark ? 0.12 : 0.06), .clear],
            startPoint: .top, endPoint: .center
        )
        .ignoresSafeArea()
    }
}

// MARK: - Plus content

private struct PlusProgressContent: View {
    let workouts: [Workout]
    @Environment(AppSettings.self) private var settings

    @State private var selectedExerciseID: UUID?
    @State private var metric: ProgressMetric = .estimatedOneRepMax

    private var tracked: [Exercise] { ProgressMetrics.trackedExercises(in: workouts) }

    /// Effective selection — the chosen exercise, or the most recent if none yet.
    private var selectedExercise: Exercise? {
        tracked.first { $0.id == selectedExerciseID } ?? tracked.first
    }

    private var points: [ExerciseSessionPoint] {
        guard let id = selectedExercise?.id else { return [] }
        return ProgressMetrics.sessionPoints(forExercise: id, in: workouts)
    }

    /// Sessions finished in the rolling last 7 days, for the weekly body map.
    private var weekWorkouts: [Workout] {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return workouts.filter { ($0.endedAt ?? $0.startedAt) >= weekAgo }
    }

    /// Front+back map of the week's training emphasis. Hidden with nothing
    /// logged in the window. The "sets per muscle" framing is the metric
    /// serious lifters program around — the analytical companion to the charts.
    @ViewBuilder
    private var weeklyMuscleSection: some View {
        let sets = weekWorkouts.muscleSets()
        if !sets.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                MuscleMapCard(setsByGroup: sets, title: "Trained this week", model: settings.bodyModel)
                Text("Effective sets per muscle over the last 7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
        }
    }

    var body: some View {
        if tracked.isEmpty {
            ContentUnavailableView(
                "No progress yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Finish a few sessions and your strength trends will appear here.")
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    weeklyMuscleSection
                    exercisePicker
                    Picker("Metric", selection: $metric) {
                        ForEach(ProgressMetric.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    chartSection
                    summarySection
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var exercisePicker: some View {
        Menu {
            ForEach(tracked) { exercise in
                Button {
                    selectedExerciseID = exercise.id
                } label: {
                    if exercise.id == selectedExercise?.id {
                        Label(exercise.name, systemImage: "checkmark")
                    } else {
                        Text(exercise.name)
                    }
                }
            }
        } label: {
            HStack(spacing: Theme.Spacing.md) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("Exercise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(selectedExercise?.name ?? "—")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Exercise: \(selectedExercise?.name ?? "none selected")")
        .accessibilityHint("Choose which exercise to chart")
    }

    @ViewBuilder
    private var chartSection: some View {
        if points.count < 2 {
            ContentUnavailableView {
                Label("Not enough data yet", systemImage: "chart.line.flattrend.xyaxis")
            } description: {
                Text("Log \(selectedExercise?.name ?? "this exercise") in at least two sessions to see a trend.")
            }
            .frame(height: 220)
        } else {
            ExerciseProgressChart(points: points, metric: metric, unit: settings.weightUnit)
                .padding(Theme.Spacing.lg)
                .glassCard()
                // Fresh selection when the exercise changes; metric stays valid.
                .id(selectedExercise?.id)
        }
    }

    private var summarySection: some View {
        let summary = ProgressMetrics.summary(of: points, metric: metric)
        let trend = trend(summary)
        return VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            SectionHeader("Summary", subtitle: nil)
            HStack(spacing: Theme.Spacing.md) {
                StatTile(title: bestTitle, value: bestValue(summary), tint: Theme.accent)
                StatTile(title: "Sessions", value: "\(summary.sessionCount)", tint: Theme.calmBlue)
                StatTile(title: "Trend", value: trend.text, tint: trend.tint, systemImage: trend.symbol)
            }
        }
    }

    // MARK: Summary helpers

    private var bestTitle: String {
        metric == .estimatedOneRepMax ? "Best 1RM" : "Best volume"
    }

    private func bestValue(_ summary: ProgressSummary) -> String {
        switch metric {
        case .estimatedOneRepMax: Formatting.weight(summary.bestKilograms, unit: settings.weightUnit)
        case .volume: Formatting.volume(summary.bestKilograms, unit: settings.weightUnit)
        }
    }

    /// Change from first to latest session, formatted with a direction.
    private func trend(_ summary: ProgressSummary) -> (text: String, symbol: String?, tint: Color) {
        guard summary.hasTrend else { return ("—", nil, Theme.calmBlue) }
        let change = summary.changeKilograms
        let magnitude = metric == .estimatedOneRepMax
            ? Formatting.weight(abs(change), unit: settings.weightUnit)
            : Formatting.volume(abs(change), unit: settings.weightUnit)
        if change > 0.05 { return ("+\(magnitude)", "arrow.up.right", Theme.success) }
        if change < -0.05 { return ("-\(magnitude)", "arrow.down.right", Theme.caution) }
        return ("No change", "arrow.right", Theme.calmBlue)
    }
}

// MARK: - Chart

private struct ExerciseProgressChart: View {
    let points: [ExerciseSessionPoint]
    let metric: ProgressMetric
    let unit: WeightUnit

    @State private var selectedDate: Date?

    private func display(_ point: ExerciseSessionPoint) -> Double {
        unit.fromKilograms(point.value(for: metric))
    }

    /// The plotted point nearest the user's selection on the x-axis.
    private var selectedPoint: ExerciseSessionPoint? {
        guard let selectedDate else { return nil }
        return points.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value(metric.label, display(point))
                )
                .foregroundStyle(.linearGradient(
                    colors: [Theme.accent.opacity(0.22), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value(metric.label, display(point))
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", point.date),
                    y: .value(metric.label, display(point))
                )
                .foregroundStyle(Theme.accent)
                .symbolSize(selectedPoint?.id == point.id ? 130 : 36)
            }

            if let selectedPoint {
                RuleMark(x: .value("Date", selectedPoint.date))
                    .foregroundStyle(Color.secondary.opacity(0.35))
                    .annotation(
                        position: .top, spacing: 6,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        callout(selectedPoint)
                    }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.notation(.compactName)))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .frame(height: 220)
        .animation(.smooth, value: metric)
        .accessibilityLabel("\(metric.label) trend across \(points.count) sessions")
        .accessibilityValue(accessibilitySummary)
    }

    private func callout(_ point: ExerciseSessionPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(point.date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(valueString(point))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
            if metric == .estimatedOneRepMax {
                Text("\(Formatting.weight(point.bestSetWeightKilograms, unit: unit)) × \(point.bestSetReps)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }

    private func valueString(_ point: ExerciseSessionPoint) -> String {
        switch metric {
        case .estimatedOneRepMax: Formatting.weight(point.bestEstimatedOneRepMaxKilograms, unit: unit)
        case .volume: Formatting.volume(point.totalVolumeKilograms, unit: unit)
        }
    }

    private var accessibilitySummary: String {
        guard let first = points.first, let last = points.last else { return "" }
        return "From \(valueString(first)) to \(valueString(last))."
    }
}

// MARK: - Locked teaser

private struct LockedProgressView: View {
    let unlock: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    HStack {
                        Text("Est. 1RM")
                            .font(.headline)
                        Spacer()
                        Text("Sample")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, Theme.Spacing.sm)
                            .padding(.vertical, 3)
                            .background(Theme.calmBlue.opacity(0.15), in: .capsule)
                            .foregroundStyle(Theme.calmBlue)
                    }
                    SampleProgressChart()
                        .frame(height: 200)
                }
                .padding(Theme.Spacing.lg)
                .glassCard()

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("See your strength climb")
                        .font(.title2.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Plus charts every lift's estimated 1RM and volume over time, and maps the muscles you trained each week — so you can see exactly what's working.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: unlock) {
                    Label("Unlock Plus", systemImage: "lock.open")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .controlSize(.extraLarge)

                Text("Your logging, history, and export stay free.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(Theme.Spacing.lg)
        }
        .accessibilityHint("Progress charts are a Plus feature")
    }
}

/// Decorative ascending sample shown to free users — not real data.
private struct SampleProgressChart: View {
    private struct Point: Identifiable {
        let id = UUID()
        let week: Int
        let value: Double
    }

    private let data: [Point] = [
        .init(week: 0, value: 80), .init(week: 1, value: 82.5), .init(week: 2, value: 82.5),
        .init(week: 3, value: 85), .init(week: 4, value: 87.5), .init(week: 5, value: 87.5),
        .init(week: 6, value: 90), .init(week: 7, value: 92.5),
    ]

    var body: some View {
        Chart(data) { point in
            AreaMark(x: .value("Week", point.week), y: .value("1RM", point.value))
                .foregroundStyle(.linearGradient(
                    colors: [Theme.accent.opacity(0.2), .clear],
                    startPoint: .top, endPoint: .bottom
                ))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Week", point.week), y: .value("1RM", point.value))
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .accessibilityHidden(true)
    }
}

// MARK: - Stat tile

private struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = Theme.accent
    var systemImage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.bold))
                }
                Text(value)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Previews

#if DEBUG
@MainActor
private enum ProgressPreview {
    /// A single exercise progressing over several sessions, for a lively preview.
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(
            for: Workout.self, Exercise.self, WorkoutTemplate.self,
            configurations: config
        )
        let context = container.mainContext
        let bench = Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        let weights: [Double] = [60, 62.5, 62.5, 65, 67.5, 70, 72.5]
        let calendar = Calendar.current
        for (index, weight) in weights.enumerated() {
            let date = calendar.date(byAdding: .day, value: -(weights.count - index) * 4, to: .now) ?? .now
            let workout = Workout(startedAt: date, endedAt: date.addingTimeInterval(3000), templateName: "Push")
            context.insert(workout)
            let entry = ExerciseEntry(order: 0, exercise: bench)
            entry.workout = workout
            context.insert(entry)
            for setIndex in 0..<3 {
                let set = SetEntry(order: setIndex, weightKilograms: weight, reps: 5, isCompleted: true)
                set.entry = entry
                context.insert(set)
            }
        }
        try? context.save()
        return container
    }()
}

#if DEBUG
#Preview("Plus") {
    ProgressDashboardView()
        .modelContainer(ProgressPreview.container)
        .environment(AppSettings())
        .environment(StoreManager.unlockedPreview)
}
#endif

#Preview("Locked") {
    ProgressDashboardView()
        .modelContainer(ProgressPreview.container)
        .environment(AppSettings())
        .environment(StoreManager())
}
#endif
