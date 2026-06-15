//
//  RoutineEditorView.swift
//  LiftCalm
//
//  Create or edit a custom routine (a user-owned WorkoutTemplate). Mirrors
//  AddExerciseView's form/save shape and reuses ExercisePickerView for adding
//  movements. Work happens on a local draft so the store is only mutated on Save.
//

import SwiftUI
import SwiftData

struct RoutineEditorView: View {
    /// Existing routine to edit, or nil to create a new one.
    var routine: WorkoutTemplate?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var summary = ""
    @State private var items: [DraftItem] = []
    @State private var showingPicker = false
    @FocusState private var nameFocused: Bool

    private var isEditing: Bool { routine != nil }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !items.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Push Day", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                Section {
                    TextField("Summary (optional)", text: $summary, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("Summary")
                } footer: {
                    Text("A short note shown on the routine card, e.g. “Chest, shoulders, triceps”.")
                }

                Section {
                    if items.isEmpty {
                        Text("No exercises yet. Add a few to build your routine.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach($items) { $item in
                            DraftItemRow(item: $item)
                        }
                        .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                        .onDelete { items.remove(atOffsets: $0) }
                    }
                    Button("Add Exercise", systemImage: "plus") { showingPicker = true }
                } header: {
                    Text("Exercises")
                } footer: {
                    if !items.isEmpty {
                        Text("Each exercise pre-fills this many sets when you start the routine.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
                if !items.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { EditButton() }
                }
            }
            .sheet(isPresented: $showingPicker) {
                ExercisePickerView { exercise in
                    items.append(DraftItem(exercise: exercise, targetSets: 3))
                }
            }
            .onAppear(perform: loadIfEditing)
            .defaultFocus($nameFocused, !isEditing)
        }
    }

    // MARK: - Load / Save

    private func loadIfEditing() {
        guard let routine, items.isEmpty, name.isEmpty else { return }
        name = routine.name
        summary = routine.summary
        items = routine.orderedItems.compactMap { item in
            item.exercise.map { DraftItem(exercise: $0, targetSets: item.targetSets) }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalSummary = resolvedSummary.isEmpty ? derivedSummary() : resolvedSummary

        let template: WorkoutTemplate
        if let routine {
            // Replace items wholesale — simpler and safe for reorder/remove.
            template = routine
            template.name = trimmedName
            template.summary = finalSummary
            for old in template.items { context.delete(old) }
        } else {
            template = WorkoutTemplate(name: trimmedName, summary: finalSummary, isBuiltIn: false)
            context.insert(template)
        }

        for (index, draft) in items.enumerated() {
            let item = TemplateItem(order: index, targetSets: draft.targetSets, exercise: draft.exercise)
            item.template = template
            context.insert(item)
        }

        try? context.save()
        dismiss()
    }

    /// A gentle fallback summary built from the distinct muscle groups trained.
    private func derivedSummary() -> String {
        let groups = items.map(\.exercise.muscleGroup)
        var seen = Set<MuscleGroup>()
        let ordered = groups.filter { seen.insert($0).inserted }
        return ordered.prefix(3).map(\.displayName).joined(separator: ", ")
    }
}

// MARK: - Draft model & row

/// A local, unsaved exercise entry. Materialised into TemplateItems on Save.
private struct DraftItem: Identifiable {
    let id = UUID()
    var exercise: Exercise
    var targetSets: Int
}

private struct DraftItemRow: View {
    @Binding var item: DraftItem

    private var setsLabel: String {
        "\(item.targetSets) set\(item.targetSets == 1 ? "" : "s")"
    }

    var body: some View {
        Stepper(value: $item.targetSets, in: 1...10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.exercise.name)
                    .font(.body)
                Text("\(item.exercise.muscleGroup.displayName) · \(setsLabel)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.exercise.name), \(setsLabel)")
        .accessibilityHint("Adjust the number of sets")
    }
}

#Preview("New") {
    RoutineEditorView()
        .modelContainer(PreviewData.container)
}

#Preview("Edit") {
    let template = try? PreviewData.container.mainContext
        .fetch(FetchDescriptor<WorkoutTemplate>()).first
    return RoutineEditorView(routine: template)
        .modelContainer(PreviewData.container)
}
