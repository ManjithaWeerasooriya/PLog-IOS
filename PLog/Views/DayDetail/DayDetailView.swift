//
//  DayDetailView.swift
//  PLog
//
//  Shows one workout day: the exercises logged, each collapsible (accordion-style, one open
//  at a time) with its sets edited inline. The session's own name/date/notes live behind the
//  title menu ("Edit Details…", a modal sheet) so exercises come first. Sets autosave;
//  there's nothing to confirm on the way out.
//

import SwiftUI
import SwiftData

struct DayDetailView: View {
    @Environment(\.modelContext) private var context

    @Environment(\.dismiss) private var dismiss

    let day: WorkoutDay

    @State private var showingExercisePicker = false
    @State private var showingDetails = false
    @State private var confirmingDelete = false
    /// The one exercise currently expanded (accordion-style — see `ExerciseEntryRows`).
    @State private var expandedEntryID: PersistentIdentifier?
    /// The one set currently open for editing, across the whole day — see `SetRow`.
    @State private var expandedSetID: PersistentIdentifier?
    /// The exercise whose history sheet is showing.
    @State private var historyExercise: Exercise?
    /// A just-added exercise to scroll into view once its rows exist.
    @State private var scrollTarget: PersistentIdentifier?
    /// The row a picked exercise will be supersetted with ("Superset with New Exercise…");
    /// `nil` when the picker is adding a plain exercise.
    @State private var supersetAnchor: SupersetBlock<ExerciseEntry>?

    var body: some View {
        ScrollViewReader { proxy in
            List {
                exercisesSection
                notesSection
            }
            // Lets a superset's "Round n" labels be shorter than a standard row; every
            // other row is taller than this on its own content.
            .environment(\.defaultMinListRowHeight, 28)
            .onChange(of: scrollTarget) { _, target in
                guard let target else { return }
                withAnimation(.snappy) { proxy.scrollTo(target, anchor: .top) }
                scrollTarget = nil
            }
        }
        .navigationTitle(day.name.isEmpty ? day.date.mediumDayLabel : day.name)
        .navigationBarTitleDisplayMode(.inline)
        // The session's metadata lives behind the title (Notes/Freeform pattern), so the
        // list can lead with the exercises.
        .toolbarTitleMenu {
            Button {
                showingDetails = true
            } label: {
                Label("Edit Details…", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Label("Delete Workout", systemImage: "trash")
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingExercisePicker = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingExercisePicker, onDismiss: { supersetAnchor = nil }) {
            ExercisePickerView(onSelect: addExercise)
        }
        .sheet(isPresented: $showingDetails) {
            SessionDetailsSheet(day: day)
        }
        // `.alert`, not `.confirmationDialog` — see AGENT.md on destructive confirmations.
        .alert("Delete This Workout?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive, action: deleteWorkout)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its exercises and sets will be removed.")
        }
        // A sheet rather than a push: this screen lives in three different stacks (Logs,
        // Calendar, Plans) and has no path of its own to push onto.
        .sheet(item: $historyExercise) { exercise in
            NavigationStack {
                ExerciseHistoryView(exercise: exercise)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { historyExercise = nil }
                        }
                    }
            }
        }
    }

    // MARK: - Sections

    /// e.g. "Sat, 19 Sep · Push / Pull / Legs" — the metadata the title doesn't carry.
    private var sessionSummary: String {
        var parts = [day.date.mediumDayLabel]
        if let planName = day.planDay?.plan?.name, !planName.isEmpty {
            parts.append(planName)
        }
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var exercisesSection: some View {
        if day.entries.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "dumbbell")
                } description: {
                    Text("Add an exercise to start logging sets.")
                }
            } header: {
                Text(sessionSummary)
            }
        } else {
            let entries = day.orderedEntries
            Section {
                // A superset is one merged block (and moves as one); everything else is a
                // plain exercise.
                ForEach(Supersets.blocks(in: entries)) { block in
                    if block.isSuperset {
                        SupersetEntryRows(
                            entries: block.members,
                            context: context,
                            isExpanded: isExpanded(block.first),
                            expandedSetID: $expandedSetID,
                            onHistory: { historyExercise = $0 },
                            onRemoveFromSuperset: removeFromSuperset,
                            onDelete: delete,
                            onUngroup: { changeSupersets { Supersets.ungroup(block, in: entries) } },
                            superset: supersetActions(for: block, in: entries)
                        )
                    } else {
                        ExerciseEntryRows(
                            entry: block.first,
                            context: context,
                            isExpanded: isExpanded(block.first),
                            expandedSetID: $expandedSetID,
                            onHistory: { historyExercise = $0 },
                            onDelete: { delete(block.first) },
                            superset: supersetActions(for: block, in: entries)
                        )
                    }
                }
                .onMove(perform: moveBlocks)
            } header: {
                Text(sessionSummary)
            }
        }
    }

    /// Only when there's something to show; tapping it opens the details sheet.
    @ViewBuilder
    private var notesSection: some View {
        if !day.notes.isEmpty {
            Section("Notes") {
                Button {
                    showingDetails = true
                } label: {
                    Text(day.notes)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .tint(.primary)
            }
        }
    }

    private func isExpanded(_ entry: ExerciseEntry) -> Binding<Bool> {
        Binding(
            get: { expandedEntryID == entry.persistentModelID },
            set: { expanded in
                expandedEntryID = expanded ? entry.persistentModelID : nil
                // Collapsing an exercise also closes whichever of its sets was open.
                if !expanded { expandedSetID = nil }
            }
        )
    }

    private func supersetActions(
        for block: SupersetBlock<ExerciseEntry>,
        in entries: [ExerciseEntry]
    ) -> SupersetActions {
        func join(_ direction: Supersets.Direction) -> (() -> Void)? {
            guard Supersets.neighbor(of: block, direction, in: entries) != nil else { return nil }
            return { changeSupersets { Supersets.join(block, with: direction, in: entries) } }
        }
        return SupersetActions(
            joinPrevious: join(.previous),
            joinNext: join(.next),
            addExercise: {
                supersetAnchor = block
                showingExercisePicker = true
            }
        )
    }

    // MARK: - Actions

    private func changeSupersets(_ change: () -> Void) {
        withAnimation(.snappy, change)
        try? context.save()
    }

    /// Creates a new entry for the chosen exercise with its first set prefilled from last
    /// time, then opens it in place — no second sheet. From "Superset with New Exercise…"
    /// it's linked in straight after its anchor row, and the merged block opens instead.
    private func addExercise(_ exercise: Exercise) {
        let entry = ExerciseEntry(exercise: exercise, order: day.entries.count)
        context.insert(entry)
        day.entries.append(entry)
        if let supersetAnchor {
            Supersets.insert(entry, joining: supersetAnchor, in: day.orderedEntries)
        }
        ExerciseEntryViewModel.prefill(entry, in: context)
        try? context.save()
        let opened = supersetAnchor?.first ?? entry
        withAnimation(.snappy) {
            expandedEntryID = opened.persistentModelID
            expandedSetID = entry.orderedSets.first?.persistentModelID
        }
        scrollTarget = opened.persistentModelID
    }

    private func removeFromSuperset(_ entry: ExerciseEntry) {
        changeSupersets { Supersets.remove(entry, in: day.orderedEntries) }
    }

    private func deleteWorkout() {
        context.delete(day)
        try? context.save()
        dismiss()
    }

    private func delete(_ entry: ExerciseEntry) {
        withAnimation(.snappy) {
            if expandedEntryID == entry.persistentModelID {
                expandedEntryID = nil
                expandedSetID = nil
            }
            day.entries.removeAll { $0 === entry }
            context.delete(entry)
            // Its superset partner may now be on its own.
            Supersets.normalize(day.orderedEntries)
        }
        try? context.save()
    }

    /// Offsets are block offsets — a superset drags as one row.
    private func moveBlocks(from source: IndexSet, to destination: Int) {
        Supersets.moveBlocks(in: day.orderedEntries, from: source, to: destination)
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        DayDetailView(day: SampleData.recentDay)
    }
    .modelContainer(SampleData.container)
}
