//
//  AddExerciseView.swift
//  LiftCalm
//
//  Create a custom exercise. Inserts into the store and optionally hands the
//  new movement straight back to the caller (e.g. to add it to a workout).
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    /// Optional callback invoked with the created exercise after saving.
    var onCreate: ((Exercise) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .chest
    @State private var equipment: Equipment = .barbell
    @State private var notes = ""
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("e.g. Cable Crossover", text: $name)
                        .focused($nameFocused)
                        .submitLabel(.done)
                }
                Section("Muscle Group") {
                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                }
                Section("Equipment") {
                    Picker("Equipment", selection: $equipment) {
                        ForEach(Equipment.allCases) { item in
                            Label(item.displayName, systemImage: item.symbol).tag(item)
                        }
                    }
                }
                Section {
                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Cues or setup reminders. Stays on this device.")
                }
            }
            .navigationTitle("New Exercise")
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
            }
            .defaultFocus($nameFocused, true)
        }
    }

    private func save() {
        let exercise = Exercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            muscleGroup: muscleGroup,
            equipment: equipment,
            isCustom: true,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        context.insert(exercise)
        try? context.save()
        onCreate?(exercise)
        dismiss()
    }
}

#Preview {
    AddExerciseView()
        .modelContainer(PreviewData.container)
}
