//
//  ActiveWorkoutView.swift
//  LiftCalm
//
//  The hero screen. One section per exercise; fast set logging; a rest timer
//  docked at the bottom. Focus spans the whole list so weight → reps flows
//  without leaving the keyboard.
//

import SwiftUI
import SwiftData

struct ActiveWorkoutView: View {
    @Environment(SessionController.self) private var session
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext

    @FocusState private var focus: SetField?
    @State private var showingPicker = false
    @State private var showingFinishConfirm = false
    @State private var showingDiscardConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if let workout = session.activeWorkout {
                    workoutList(workout)
                } else {
                    ContentUnavailableView(
                        "No active workout",
                        systemImage: "dumbbell",
                        description: Text("Start a session from the Today tab.")
                    )
                }
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .toolbar { keyboardToolbar }
            .safeAreaInset(edge: .bottom) {
                if session.isResting { RestTimerBar() }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    if let workout = session.activeWorkout {
                        session.addExercise(exercise, to: workout)
                    }
                }
            }
            .confirmationDialog("Finish this workout?", isPresented: $showingFinishConfirm) {
                Button("Finish Workout") { finish() }
                Button("Keep Going", role: .cancel) { }
            } message: {
                Text("Your session will be saved to history.")
            }
            .confirmationDialog("Discard this workout?", isPresented: $showingDiscardConfirm) {
                Button("Discard", role: .destructive) { discard() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This can't be undone.")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { session.refreshRestState() }
        }
    }

    // MARK: - List

    private func workoutList(_ workout: Workout) -> some View {
        List {
            SessionSummaryHeader(workout: workout)
                .listRowInsets(.init(top: 4, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

            ForEach(workout.orderedEntries) { entry in
                exerciseSection(entry)
            }

            Button {
                showingPicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.Spacing.sm)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if workout.entries.isEmpty {
                ContentUnavailableView {
                    Label("Add your first exercise", systemImage: "plus.circle")
                } description: {
                    Text("Search the library to start logging sets.")
                } actions: {
                    Button("Add Exercise") { showingPicker = true }
                        .buttonStyle(.glassProminentCompat)
                }
            }
        }
    }

    private func exerciseSection(_ entry: ExerciseEntry) -> some View {
        Section {
            ColumnLabels(unit: settings.weightUnit)
                .listRowSeparator(.hidden)

            ForEach(Array(entry.orderedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, displayNumber: index + 1, focus: $focus)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            session.removeSet(set)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            set.isWarmup.toggle()
                        } label: {
                            Label("Warm-up", systemImage: "flame")
                        }
                        .tint(Theme.caution)
                    }
            }

            Button {
                session.addSet(to: entry)
            } label: {
                Label("Add Set", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            ExerciseSectionHeader(entry: entry) {
                session.removeEntry(entry)
            }
        }
    }

    // MARK: - Toolbars

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Close", systemImage: "chevron.down") { dismiss() }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Finish") { showingFinishConfirm = true }
                .fontWeight(.semibold)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button("Add Exercise", systemImage: "plus") { showingPicker = true }
                Button("Discard Workout", systemImage: "trash", role: .destructive) {
                    showingDiscardConfirm = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    @ToolbarContentBuilder
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button("Done") { focus = nil }
        }
    }

    // MARK: - Actions

    private func finish() {
        focus = nil
        session.finishWorkout()
        // A finished session changes readiness/recent activity — refresh the widget.
        WidgetBridge.refresh(context: modelContext)
        dismiss()
    }

    private func discard() {
        focus = nil
        session.discardWorkout()
        dismiss()
    }
}

// MARK: - Column labels

private struct ColumnLabels: View {
    let unit: WeightUnit

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Text("SET").frame(width: 26)
            Text(unit.abbreviation.uppercased()).frame(maxWidth: .infinity)
            Text("REPS").frame(maxWidth: .infinity)
            Text("RPE").frame(width: 42)
            Color.clear.frame(width: 40)
        }
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
}

#Preview {
    let container = PreviewData.container
    let session = SessionController()
    let workout = PreviewData.activeWorkout(in: container.mainContext)
    session.configure(context: container.mainContext, settings: AppSettings(), notifications: NotificationManager())
    session.resume(workout)
    return ActiveWorkoutView()
        .modelContainer(container)
        .environment(AppSettings())
        .environment(session)
}
