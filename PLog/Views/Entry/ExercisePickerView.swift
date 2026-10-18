//
//  ExercisePickerView.swift
//  PLog
//
//  A searchable sheet for choosing which master-list exercise to log on a day.
//  If the exercise doesn't exist yet, it can be created inline.
//

import SwiftUI
import SwiftData

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Called with the chosen exercise; the sheet dismisses itself afterward.
    var onSelect: (Exercise) -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showingAddExercise = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedResults, id: \.group) { section in
                    Section(section.group.displayName) {
                        ForEach(section.items) { exercise in
                            Button {
                                choose(exercise)
                            } label: {
                                HStack {
                                    Text(exercise.name)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    MuscleGroupIcon(exercise.category)
                                }
                            }
                        }
                    }
                }

                if !searchText.isEmpty && !hasExactMatch {
                    Section {
                        Button {
                            showingAddExercise = true
                        } label: {
                            Label("Create \"\(searchText)\"", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExercise = true
                    } label: {
                        Label("New Exercise", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseView(prefilledName: searchText) { created in
                    choose(created)
                }
            }
        }
    }

    // MARK: - Filtering

    private var filtered: [Exercise] {
        guard !searchText.isEmpty else { return exercises }
        return exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var hasExactMatch: Bool {
        exercises.contains { $0.name.localizedCaseInsensitiveCompare(searchText) == .orderedSame }
    }

    private var groupedResults: [(group: MuscleGroup, items: [Exercise])] {
        MuscleGroup.allCases.compactMap { group in
            let items = filtered.filter { $0.category == group }
            return items.isEmpty ? nil : (group, items)
        }
    }

    private func choose(_ exercise: Exercise) {
        onSelect(exercise)
        dismiss()
    }
}

#Preview {
    ExercisePickerView(onSelect: { _ in })
        .modelContainer(SampleData.container)
}
