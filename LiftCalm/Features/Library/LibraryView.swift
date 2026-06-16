//
//  LibraryView.swift
//  LiftCalm
//
//  Two libraries in one: the exercise catalogue and your routines. Custom
//  exercises and custom routines can be deleted; built-ins are kept (deleting
//  them would break templates and history links). Saving more than the free
//  routine allowance requires LiftCalm Plus.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Environment(StoreManager.self) private var store
    @Environment(\.presentPaywall) private var presentPaywall
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    @State private var tab: LibraryTab = .exercises
    @State private var searchText = ""
    @State private var showingCreateExercise = false
    @State private var creatingRoutine = false
    @State private var generatingRoutine = false
    @State private var pendingManual = false
    @State private var editingRoutine: WorkoutTemplate?

    var body: some View {
        NavigationStack {
            Group {
                switch tab {
                case .exercises: exercisesList
                case .routines: routinesList
                }
            }
            .safeAreaInset(edge: .top) { tabPicker }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(addTitle, systemImage: "plus") { add() }
                }
            }
            .sheet(isPresented: $showingCreateExercise) {
                AddExerciseView()
            }
            .sheet(isPresented: $creatingRoutine) {
                RoutineEditorView()
            }
            .sheet(isPresented: $generatingRoutine, onDismiss: {
                // Hand off to the manual editor if the user chose that escape hatch
                // (presenting only after this sheet has fully dismissed avoids a race).
                if pendingManual {
                    pendingManual = false
                    creatingRoutine = true
                }
            }) {
                RoutineWizardView(onManual: { pendingManual = true })
            }
            .sheet(item: $editingRoutine) { routine in
                RoutineEditorView(routine: routine)
            }
        }
    }

    private var tabPicker: some View {
        Picker("Library section", selection: $tab) {
            ForEach(LibraryTab.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        .background(.bar)
    }

    // MARK: - Exercises

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Group by muscle so the list reads like a coaching reference.
    private var groupedExercises: [(group: MuscleGroup, items: [Exercise])] {
        Dictionary(grouping: filteredExercises, by: \.muscleGroup)
            .map { (group: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.group.displayName < $1.group.displayName }
    }

    private var exercisesList: some View {
        List {
            ForEach(groupedExercises, id: \.group) { section in
                Section(section.group.displayName) {
                    ForEach(section.items) { exercise in
                        ExerciseLibraryRow(exercise: exercise)
                            .swipeActions(edge: .trailing) {
                                if exercise.isCustom {
                                    Button(role: .destructive) {
                                        delete(exercise)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if filteredExercises.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .searchable(text: $searchText, prompt: "Search exercises")
    }

    // MARK: - Routines

    private var customTemplates: [WorkoutTemplate] { templates.filter { !$0.isBuiltIn } }
    private var builtInTemplates: [WorkoutTemplate] { templates.filter(\.isBuiltIn) }

    private var routinesList: some View {
        List {
            if aiAvailable {
                Section {
                    Button { startAIGeneration() } label: { aiGenerateCard }
                        .buttonStyle(.plain)
                }
            }
            if !customTemplates.isEmpty {
                Section {
                    ForEach(customTemplates) { template in
                        Button {
                            editingRoutine = template
                        } label: {
                            RoutineRow(template: template, isCustom: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                delete(template)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("My Routines")
                } footer: {
                    if !store.isPlus {
                        Text("Free plan includes \(PlusPolicy.freeCustomRoutineLimit) routines. Unlock Plus for unlimited.")
                    }
                }
            }
            Section("Built-in") {
                ForEach(builtInTemplates) { template in
                    RoutineRow(template: template, isCustom: false)
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    /// Prominent entry point for on-device AI generation, shown atop the routines
    /// list so the feature isn't buried behind the "+" button.
    private var aiGenerateCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("Generate with AI")
                    .font(.body.weight(.semibold))
                Text("Build a routine on your device")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Generate a routine with AI")
        .accessibilityHint("Builds a routine on your device")
    }

    // MARK: - Actions

    private var addTitle: String { tab == .exercises ? "Add Exercise" : "Add Routine" }

    /// Hide the AI option entirely on hardware that can never run the on-device
    /// model; transient states (downloading / Apple Intelligence off) still show
    /// it so the wizard can guide the user to fix them.
    private var aiAvailable: Bool {
        switch RoutineWizardService.availability {
        case .deviceNotEligible, .unavailable: false
        default: true
        }
    }

    private func add() {
        switch tab {
        case .exercises:
            showingCreateExercise = true
        case .routines:
            if PlusPolicy.canCreateCustomRoutine(currentCount: customTemplates.count, isPlus: store.isPlus) {
                creatingRoutine = true
            } else {
                presentPaywall(.routines)
            }
        }
    }

    /// AI generation produces a custom routine, so it respects the same free-plan
    /// cap as manual creation.
    private func startAIGeneration() {
        if PlusPolicy.canCreateCustomRoutine(currentCount: customTemplates.count, isPlus: store.isPlus) {
            generatingRoutine = true
        } else {
            presentPaywall(.routines)
        }
    }

    private func delete(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }

    private func delete(_ template: WorkoutTemplate) {
        // Cascade removes the template's items.
        context.delete(template)
        try? context.save()
    }
}

private enum LibraryTab: String, CaseIterable, Identifiable {
    case exercises, routines
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

private struct RoutineRow: View {
    let template: WorkoutTemplate
    let isCustom: Bool

    private var exerciseCount: Int { template.items.count }

    /// Built-in routines get a distinct glyph keyed off their name; custom
    /// routines fall back to the generic list symbol.
    private var symbolName: String {
        switch template.name {
        case "Push":      return "figure.strengthtraining.traditional"
        case "Pull":      return "figure.rower"
        case "Legs":      return "figure.strengthtraining.functional"
        case "Full Body": return "figure.mixed.cardio"
        default:          return "list.bullet.rectangle.portrait"
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            Image(systemName: symbolName)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(template.name)
                    .font(.body)
                if !template.summary.isEmpty {
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text("\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if isCustom {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(.rect)
        .padding(.vertical, Theme.Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(template.name), \(exerciseCount) exercises")
        .accessibilityHint(isCustom ? "Edit this routine" : "")
    }
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
        .environment(AppSettings())
        .environment(StoreManager())
}
