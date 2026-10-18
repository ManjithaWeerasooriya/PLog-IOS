//
//  ExerciseLibraryView.swift
//  PLog
//
//  The Exercises tab: the master list, searchable, grouped by muscle group, with
//  add/edit/delete. Tapping an exercise opens its progress history. Owns the tab's
//  `NavigationStack`.
//

import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var categoryFilter: MuscleGroup?
    @State private var showingAddExercise = false
    @State private var editingExercise: Exercise?

    /// The exercise staged for deletion, pending the alert below. `.alert` (not
    /// `.confirmationDialog`) is deliberate: it's always centered, so there's no anchor to
    /// mis-place, and it's attached once at the root rather than per-row — attaching a
    /// presentation to a row that a `.swipeActions` button just collapsed/tore down was
    /// unreliable (the presentation request could be lost in that transient rebuild).
    @State private var pendingDeleteExercise: Exercise?

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(for: Exercise.self) { exercise in
                    ExerciseHistoryView(exercise: exercise)
                }
        }
    }

    private var content: some View {
        Group {
            if exercises.isEmpty {
                emptyState
            } else {
                libraryList
            }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                categoryMenu
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView()
        }
        .sheet(item: $editingExercise) { exercise in
            AddExerciseView(exercise: exercise)
        }
        .alert(
            deleteConfirmationTitle,
            isPresented: isShowingDeleteConfirmation
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteExercise {
                    confirmDelete(pendingDeleteExercise)
                }
            }
            Button("Cancel", role: .cancel) { pendingDeleteExercise = nil }
        } message: {
            Text("Logged sets that used it are kept, just no longer linked to an exercise.")
        }
    }

    // MARK: - List

    private var libraryList: some View {
        List {
            ForEach(groupedResults, id: \.group) { section in
                Section {
                    ForEach(section.items) { exercise in
                        NavigationLink(value: exercise) {
                            row(for: exercise)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingExercise = exercise
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                pendingDeleteExercise = exercise
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Label {
                        Text(section.group.displayName)
                    } icon: {
                        MuscleGroupIcon(section.group, size: 20, relativeTo: .footnote)
                    }
                }
            }
        }
    }

    private func row(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                if let muscles = muscleSummary(for: exercise) {
                    Text(muscles)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                let sessions = exercise.entries.filter { $0.workoutDay != nil }.count
                Text(sessions == 0 ? "No sessions yet" : "\(sessions) \(sessions == 1 ? "session" : "sessions") logged")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    /// "Quads, Glutes · Secondary: Hamstrings" — only for exercises with more than one group,
    /// so a single-group exercise isn't labelled with its own section's name.
    private func muscleSummary(for exercise: Exercise) -> String? {
        let primary = exercise.primaryMuscles
        let secondary = exercise.secondaryMuscles
        guard primary.count > 1 || !secondary.isEmpty else { return nil }
        var parts = [MuscleGroup.names(primary)]
        if !secondary.isEmpty {
            parts.append("Secondary: \(MuscleGroup.names(secondary))")
        }
        return parts.joined(separator: " · ")
    }

    private var categoryMenu: some View {
        Menu {
            Button("All Muscle Groups") { categoryFilter = nil }
            Divider()
            ForEach(MuscleGroup.allCases) { group in
                Button {
                    categoryFilter = group
                } label: {
                    Label {
                        Text(group.displayName)
                    } icon: {
                        group.image
                    }
                }
            }
        } label: {
            Label(
                categoryFilter?.displayName ?? "Filter",
                systemImage: categoryFilter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Exercises", systemImage: "dumbbell")
        } description: {
            Text("Build your master list of exercises to log during workouts.")
        } actions: {
            Button("Add Exercise") { showingAddExercise = true }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Filtering

    private var groupedResults: [(group: MuscleGroup, items: [Exercise])] {
        let filtered = exercises.filter { exercise in
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = categoryFilter.map(exercise.primaryMuscles.contains) ?? true
            return matchesSearch && matchesCategory
        }
        // An exercise appears under every primary group (never a secondary one).
        return MuscleGroup.allCases.compactMap { group in
            let items = filtered.filter { $0.primaryMuscles.contains(group) }
            return items.isEmpty ? nil : (group, items)
        }
    }

    // MARK: - Deletion

    private var isShowingDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { pendingDeleteExercise != nil },
            set: { isPresented in
                if !isPresented { pendingDeleteExercise = nil }
            }
        )
    }

    private func confirmDelete(_ exercise: Exercise) {
        context.delete(exercise)
        pendingDeleteExercise = nil
        try? context.save()
    }

    private var deleteConfirmationTitle: String {
        let name = pendingDeleteExercise?.name ?? ""
        return "Delete “\(name.isEmpty ? "Exercise" : name)”?"
    }
}

#Preview {
    ExerciseLibraryView()
        .modelContainer(SampleData.container)
}
