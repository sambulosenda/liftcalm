//
//  ExercisePickerView.swift
//  LiftCalm
//
//  Searchable library picker used to add a movement to the active workout.
//  Supports text search plus equipment filtering, and creating a custom lift.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    /// Called with the chosen exercise; the sheet dismisses itself afterward.
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var equipmentFilter: Equipment?
    @State private var showingCreate = false

    /// Filtered + still stably identified (elements are @Model with unique ids),
    /// so recomputing per body is safe for ForEach identity.
    private var filtered: [Exercise] {
        exercises.filter { exercise in
            let matchesText = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesEquipment = equipmentFilter == nil
                || exercise.equipment == equipmentFilter
            return matchesText && matchesEquipment
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { exercise in
                    Button {
                        onSelect(exercise)
                        dismiss()
                    } label: {
                        ExerciseLibraryRow(exercise: exercise)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .overlay {
                if filtered.isEmpty {
                    emptyState
                }
            }
            .safeAreaInset(edge: .top) {
                equipmentChips
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Custom", systemImage: "plus") { showingCreate = true }
                }
            }
            .sheet(isPresented: $showingCreate) {
                AddExerciseView { newExercise in
                    onSelect(newExercise)
                    dismiss()
                }
            }
        }
    }

    private var equipmentChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(title: "All", isSelected: equipmentFilter == nil) {
                    equipmentFilter = nil
                }
                ForEach(Equipment.allCases) { equipment in
                    FilterChip(
                        title: equipment.displayName,
                        systemImage: equipment.symbol,
                        isSelected: equipmentFilter == equipment
                    ) {
                        equipmentFilter = equipmentFilter == equipment ? nil : equipment
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            ContentUnavailableView(
                "No exercises",
                systemImage: "magnifyingglass",
                description: Text("Try a different filter or add a custom exercise.")
            )
        }
    }
}

// MARK: - Rows & chips

struct ExerciseLibraryRow: View {
    let exercise: Exercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: exercise.equipment.symbol)
                .font(.body)
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.12), in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.body)
                Text(exercise.muscleGroup.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isCustom {
                Text("Custom")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: .capsule)
            }
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Adds \(exercise.name) to your workout")
    }
}

struct FilterChip: View {
    let title: String
    var systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                Text(title)
            } icon: {
                if let systemImage { Image(systemName: systemImage) }
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(
                isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
