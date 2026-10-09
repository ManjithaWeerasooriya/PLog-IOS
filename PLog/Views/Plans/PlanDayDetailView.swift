//
//  PlanDayDetailView.swift
//  PLog
//
//  Edit one day template: its name and the exercises with target sets × reps that get
//  pre-created every time this day is logged. Everything autosaves; nothing to confirm on back.
//

import SwiftUI
import SwiftData

struct PlanDayDetailView: View {
    @Environment(\.modelContext) private var context

    @Bindable var day: PlanDay

    @State private var showingExercisePicker = false
    /// The one row currently expanded (accordion-style — see `PlanExerciseRow`); a
    /// superset is keyed by its first slot.
    @State private var expandedSlotID: PersistentIdentifier?
    /// The row a picked exercise will be supersetted with; `nil` for a plain add.
    @State private var supersetAnchor: SupersetBlock<PlanExercise>?

    var body: some View {
        List {
            Section("Day") {
                TextField("Day name", text: $day.name)
                    .font(.headline)
            }

            exercisesSection
        }
        .navigationTitle(day.name.isEmpty ? "Day" : day.name)
        .navigationBarTitleDisplayMode(.inline)
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
    }

    // MARK: - Sections

    @ViewBuilder
    private var exercisesSection: some View {
        if day.exercises.isEmpty {
            Section {
                ContentUnavailableView {
                    Label("No Exercises", systemImage: "dumbbell")
                } description: {
                    Text("Add exercises with target sets and reps. They'll be pre-filled every time you log this day.")
                }
            }
        } else {
            let slots = day.orderedExercises
            let blocks = Supersets.blocks(in: slots)
            Section {
                // A superset is one merged row (and moves or deletes as one).
                ForEach(blocks) { block in
                    if block.isSuperset {
                        PlanSupersetRow(
                            slots: block.members,
                            isExpanded: isExpanded(block.first),
                            onRemoveFromSuperset: { slot in
                                changeSupersets { Supersets.remove(slot, in: day.orderedExercises) }
                            },
                            onDelete: { slot in delete([slot]) },
                            onUngroup: { changeSupersets { Supersets.ungroup(block, in: slots) } },
                            superset: supersetActions(for: block, in: slots)
                        )
                    } else {
                        PlanExerciseRow(
                            planExercise: block.first,
                            isExpanded: isExpanded(block.first),
                            superset: supersetActions(for: block, in: slots)
                        )
                    }
                }
                .onDelete { offsets in delete(offsets.flatMap { blocks[$0].members }) }
                .onMove { source, destination in
                    Supersets.moveBlocks(in: day.orderedExercises, from: source, to: destination)
                    try? context.save()
                }
            } header: {
                Text("Exercises")
            } footer: {
                // A one-time nudge: gone once there's a superset to show the idea.
                if slots.count > 1, !blocks.contains(where: \.isSuperset) {
                    Text("Touch and hold an exercise to make a superset.")
                }
            }
        }
    }

    private func isExpanded(_ slot: PlanExercise) -> Binding<Bool> {
        Binding(
            get: { expandedSlotID == slot.persistentModelID },
            set: { expanded in expandedSlotID = expanded ? slot.persistentModelID : nil }
        )
    }

    private func supersetActions(
        for block: SupersetBlock<PlanExercise>,
        in slots: [PlanExercise]
    ) -> SupersetActions {
        func join(_ direction: Supersets.Direction) -> (() -> Void)? {
            guard Supersets.neighbor(of: block, direction, in: slots) != nil else { return nil }
            return { changeSupersets { Supersets.join(block, with: direction, in: slots) } }
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

    /// Appends through `day.exercises` (not by setting `slot.planDay`) so Observation fires
    /// on the day and this screen refreshes; setting only the inverse side doesn't notify.
    /// From "Superset with New Exercise…" the slot is linked in after its anchor row, at
    /// the superset's rounds, and the merged row opens.
    private func addExercise(_ exercise: Exercise) {
        let slot = PlanExercise(exercise: exercise, order: day.exercises.count)
        context.insert(slot)
        day.exercises.append(slot)
        if let supersetAnchor {
            slot.targetSets = supersetAnchor.members.map(\.targetSets).max() ?? slot.targetSets
            Supersets.insert(slot, joining: supersetAnchor, in: day.orderedExercises)
            withAnimation(.snappy) { expandedSlotID = supersetAnchor.first.persistentModelID }
        }
        try? context.save()
    }

    private func delete(_ doomed: [PlanExercise]) {
        for slot in doomed {
            day.exercises.removeAll { $0 === slot }
            context.delete(slot)
        }
        let remaining = day.orderedExercises
        Supersets.renumber(remaining)
        // A deleted slot's superset partner may now be on its own.
        Supersets.normalize(remaining)
        try? context.save()
    }
}

#Preview {
    NavigationStack {
        PlanDayDetailView(day: SampleData.pushDay)
    }
    .modelContainer(SampleData.container)
}
