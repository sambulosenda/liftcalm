//
//  RoutineWizardView.swift
//  LiftCalm
//
//  "Generate with AI" sheet: collects a short brief, asks the on-device model
//  for a routine (RoutineWizardService), then lets the user tweak sets and save
//  it as a normal custom routine (a WorkoutTemplate, isBuiltIn: false). The save
//  path mirrors RoutineEditorView so generated and hand-built routines are
//  identical once stored.
//

import SwiftUI
import SwiftData

struct RoutineWizardView: View {
    /// Called when the user opts out of AI and wants the manual editor instead.
    /// The caller presents RoutineEditorView from the sheet's `onDismiss`.
    var onManual: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    // Inputs
    @State private var focus: TrainingFocus = .fullBody
    @State private var goal: TrainingGoal = .hypertrophy
    @State private var experience: ExperienceLevel = .intermediate
    @State private var exerciseCount = 5
    @State private var selectedEquipment: Set<Equipment> = Set(Equipment.allCases.filter { $0 != .other })

    // Generation state
    @State private var phase: Phase = .input
    @State private var availability: AIModel.Availability = .ready
    @State private var reviewItems: [ReviewItem] = []
    @State private var draftName = ""
    @State private var draftSummary = ""
    @State private var variation = 0
    @State private var generatedToken = false
    @State private var task: Task<Void, Never>?

    enum Phase: Equatable { case input, generating, review, empty, failed(String) }

    struct ReviewItem: Identifiable {
        let id = UUID()
        let exercise: Exercise
        var targetSets: Int
    }

    var body: some View {
        NavigationStack {
            Group {
                if availability == .ready {
                    switch phase {
                    case .input:         inputForm
                    case .generating:    generatingView
                    case .review:        reviewForm
                    case .empty:         emptyView
                    case .failed(let m): failedView(m)
                    }
                } else {
                    unavailableView
                }
            }
            .navigationTitle("Generate Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .sensoryFeedback(.success, trigger: generatedToken)
            .onAppear { availability = AIModel.availability }
            .onDisappear { task?.cancel() }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Cancel") { task?.cancel(); dismiss() }
        }
        if phase == .review {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    private var canSave: Bool {
        !draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !reviewItems.isEmpty
    }

    // MARK: - Input

    private var inputForm: some View {
        Form {
            Section {
                Picker("Focus", selection: $focus) {
                    ForEach(TrainingFocus.allCases) { Text($0.title).tag($0) }
                }
                Picker("Goal", selection: $goal) {
                    ForEach(TrainingGoal.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Experience", selection: $experience) {
                    ForEach(ExperienceLevel.allCases) { Text($0.displayName).tag($0) }
                }
                Stepper("Exercises: \(exerciseCount)", value: $exerciseCount, in: 3...8)
            } header: {
                Text("What do you want to train?")
            }

            Section {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: Theme.Spacing.sm)],
                    spacing: Theme.Spacing.sm
                ) {
                    ForEach(Equipment.allCases.filter { $0 != .other }) { equipmentChip($0) }
                }
                .padding(.vertical, Theme.Spacing.xs)
            } header: {
                Text("Equipment")
            } footer: {
                Text("Only exercises using the selected equipment will be chosen.")
            }

            Section {
                Button { generate() } label: {
                    Label("Generate Routine", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminentCompat)
                .listRowBackground(Color.clear)
            } footer: {
                Label("Runs entirely on your device. Nothing is sent to the internet.",
                      systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func equipmentChip(_ equip: Equipment) -> some View {
        let isOn = selectedEquipment.contains(equip)
        return Button {
            if isOn { selectedEquipment.remove(equip) } else { selectedEquipment.insert(equip) }
        } label: {
            Label(equip.displayName, systemImage: equip.symbol)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.sm)
                .foregroundStyle(isOn ? .white : .primary)
                .background(
                    isOn ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary),
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    // MARK: - Generating

    private var generatingView: some View {
        VStack(spacing: Theme.Spacing.lg) {
            ProgressView().controlSize(.large)
            Text("Building your routine…")
                .font(.headline)
            Text("Thinking it through on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Review

    private var reviewForm: some View {
        Form {
            Section("Name") {
                TextField("Routine name", text: $draftName)
                    .submitLabel(.done)
            }
            if !draftSummary.isEmpty {
                Section("Summary") {
                    Text(draftSummary).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach($reviewItems) { $item in
                    Stepper(value: $item.targetSets, in: 1...10) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(item.exercise.name).font(.body)
                            Text("\(item.exercise.muscleGroup.displayName) · \(item.targetSets) set\(item.targetSets == 1 ? "" : "s")")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.exercise.name), \(item.targetSets) sets")
                    .accessibilityHint("Adjust the number of sets")
                }
                .onDelete { reviewItems.remove(atOffsets: $0) }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Tweak the sets, swipe to remove anything, then save.")
            }
            Section {
                Button {
                    variation += 1
                    generate()
                } label: {
                    Label("Generate again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .listRowBackground(Color.clear)
            }
        }
    }

    // MARK: - Empty / failed / unavailable

    private var emptyView: some View {
        ContentUnavailableView {
            Label("No routine built", systemImage: "questionmark.folder")
        } description: {
            Text("The coach couldn't put together a full routine from these settings. Try a different focus or turn on more equipment.")
        } actions: {
            Button("Adjust settings") { phase = .input }
                .buttonStyle(.glassProminentCompat)
        }
    }

    private func failedView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Generation failed", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try again") { generate() }
                .buttonStyle(.glassProminentCompat)
            Button("Back to settings") { phase = .input }
        }
    }

    private var unavailableView: some View {
        ContentUnavailableView {
            Label(unavailableTitle, systemImage: "exclamationmark.triangle")
        } description: {
            Text(unavailableMessage)
        } actions: {
            Button("Build one myself") {
                onManual()
                dismiss()
            }
            .buttonStyle(.glassProminentCompat)
            if availability == .modelDownloading {
                Button("Check again") { availability = AIModel.availability }
            }
        }
    }

    private var unavailableTitle: String {
        switch availability {
        case .deviceNotEligible:    "Not available on this device"
        case .appleIntelligenceOff: "Apple Intelligence is off"
        case .modelDownloading:     "Getting ready"
        default:                    "AI is unavailable"
        }
    }

    private var unavailableMessage: String {
        switch availability {
        case .deviceNotEligible:
            "On-device routine generation needs a device that supports Apple Intelligence. You can still build a routine by hand."
        case .appleIntelligenceOff:
            "Turn on Apple Intelligence in Settings to generate routines on your device — or build one by hand."
        case .modelDownloading:
            "The on-device model is still downloading. Try again shortly, or build a routine by hand."
        default:
            "On-device generation isn't available right now. You can still build a routine by hand."
        }
    }

    // MARK: - Generation flow

    private func generate() {
        task?.cancel()
        let names = allowedExerciseNames()
        guard names.count >= 3 else { phase = .empty; return }
        phase = .generating
        let request = RoutineRequest(
            focus: focus, goal: goal, experience: experience,
            exerciseCount: exerciseCount, variation: variation
        )
        task = Task { @MainActor in
            do {
                let result = try await RoutineWizardService.generate(request: request, allowedExercises: names)
                if Task.isCancelled { return }
                apply(result)
            } catch is CancellationError {
                // User moved on — ignore.
            } catch {
                if Task.isCancelled { return }
                phase = .failed("Something went wrong while generating. Please try again.")
            }
        }
    }

    private func apply(_ result: GeneratedRoutine) {
        // Resolve against the whole library (not just the equipment-filtered
        // prompt list) so a valid pick is never dropped; indices map into `exercises`.
        let pairs = RoutineWizardService.resolved(
            result.exercises.map { ($0.name, $0.targetSets) },
            catalogNames: exercises.map(\.name)
        )
        guard pairs.count >= 2 else { phase = .empty; return }
        let trimmedName = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draftName = trimmedName.isEmpty ? focus.title : trimmedName
        draftSummary = result.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        reviewItems = pairs.map { ReviewItem(exercise: exercises[$0.index], targetSets: $0.targetSets) }
        phase = .review
        generatedToken.toggle()   // success haptic — the routine is ready
    }

    /// Names of library exercises matching the chosen equipment (falls back to
    /// the whole library if the user deselects everything).
    private func allowedExerciseNames() -> [String] {
        let matching = exercises.filter { selectedEquipment.contains($0.equipment) }
        return (matching.isEmpty ? exercises : matching).map(\.name)
    }

    // MARK: - Save

    private func save() {
        let template = WorkoutTemplate(
            name: draftName.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: draftSummary.trimmingCharacters(in: .whitespacesAndNewlines),
            isBuiltIn: false
        )
        context.insert(template)
        for (index, item) in reviewItems.enumerated() {
            let templateItem = TemplateItem(order: index, targetSets: item.targetSets, exercise: item.exercise)
            templateItem.template = template
            context.insert(templateItem)
        }
        try? context.save()
        dismiss()
    }
}

#Preview {
    RoutineWizardView()
        .modelContainer(PreviewData.container)
}
