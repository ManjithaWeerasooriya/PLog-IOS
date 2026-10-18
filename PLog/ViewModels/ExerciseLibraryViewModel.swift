//
//  ExerciseLibraryViewModel.swift
//  PLog
//
//  Search/filter and mutation logic for the master exercise library.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ExerciseLibraryViewModel {
    var searchText: String = ""
    var categoryFilter: MuscleGroup?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Filters a fetched list by search text and optional category, grouped by muscle group.
    func groupedResults(from exercises: [Exercise]) -> [(group: MuscleGroup, items: [Exercise])] {
        let filtered = exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter.map(exercise.primaryMuscles.contains) ?? true
            return matchesSearch && matchesCategory
        }

        return MuscleGroup.allCases.compactMap { group in
            let items = filtered
                .filter { $0.primaryMuscles.contains(group) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return items.isEmpty ? nil : (group, items)
        }
    }

    /// Adds a new exercise to the master list. Returns the created exercise.
    @discardableResult
    func addExercise(name: String, category: MuscleGroup) -> Exercise? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let exercise = Exercise(name: trimmed, category: category)
        context.insert(exercise)
        try? context.save()
        return exercise
    }

    /// Deletes an exercise from the master list. Historical entries keep their logged sets
    /// (the relationship nullifies rather than cascades).
    func delete(_ exercise: Exercise) {
        context.delete(exercise)
        try? context.save()
    }
}
