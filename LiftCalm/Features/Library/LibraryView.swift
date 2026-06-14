//
//  LibraryView.swift
//  LiftCalm
//
//  Browse and manage the exercise library. Custom exercises can be deleted;
//  built-ins are kept (deleting them would break templates and history links).
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var showingCreate = false

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    /// Group by muscle so the list reads like a coaching reference.
    private var grouped: [(group: MuscleGroup, items: [Exercise])] {
        Dictionary(grouping: filtered, by: \.muscleGroup)
            .map { (group: $0.key, items: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.group.displayName < $1.group.displayName }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped, id: \.group) { section in
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
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add", systemImage: "plus") { showingCreate = true }
                }
            }
            .sheet(isPresented: $showingCreate) {
                AddExerciseView()
            }
        }
    }

    private func delete(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }
}

#Preview {
    LibraryView()
        .modelContainer(PreviewData.container)
        .environment(AppSettings())
}
