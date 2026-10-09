//
//  PlanSupersetRow.swift
//  PLog
//
//  A superset in a day template, merged into one `DisclosureGroup`: the label stacks the
//  exercises on a chain with each one's target reps, and the content is one Rounds stepper
//  for the whole superset (it sets every slot's `targetSets`) plus a reps stepper per
//  exercise. Same system expand/collapse as `PlanExerciseRow`.
//

import SwiftUI
import SwiftData

struct PlanSupersetRow: View {
    let slots: [PlanExercise]
    /// Controlled by the parent so only one row is expanded at a time — see `PlanDayDetailView`.
    @Binding var isExpanded: Bool
    var onRemoveFromSuperset: (PlanExercise) -> Void
    var onDelete: (PlanExercise) -> Void
    var onUngroup: () -> Void
    var superset: SupersetActions

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 12) {
                NumberStepper(title: "Rounds", intValue: roundsBinding, range: 1...20, style: .row)
                ForEach(Array(slots.enumerated()), id: \.element.persistentModelID) { index, slot in
                    NumberStepper(
                        title: "\(Supersets.letter(for: index)) · \(name(of: slot)) reps",
                        intValue: repsBinding(for: slot),
                        range: 1...100,
                        style: .row
                    )
                }
            }
            .padding(.vertical, 8)
            // The steppers are a child row; swipes and drags there must not act on the block.
            .deleteDisabled(true)
            .moveDisabled(true)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                SupersetTitle(rounds: rounds)
                SupersetChain(items: chainItems)
            }
            .padding(.vertical, 4)
            // On the label only: a long-press on the steppers is hold-to-repeat.
            .contextMenu { menu }
            .supersetAccessibilityActions(superset, isSuperset: true)
            .accessibilityAction(named: "Ungroup Superset", onUngroup)
        }
        .accessibilityHint("Double-tap to edit rounds and reps")
    }

    @ViewBuilder
    private var menu: some View {
        ForEach(Array(slots.enumerated()), id: \.element.persistentModelID) { index, slot in
            Menu {
                Button {
                    onRemoveFromSuperset(slot)
                } label: {
                    Label("Remove from Superset", systemImage: "minus.circle")
                }
                Button(role: .destructive) {
                    onDelete(slot)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Label(name(of: slot), systemImage: index < 26 ? "\(Supersets.letter(for: index).lowercased()).circle" : "circle")
            }
        }
        Divider()
        SupersetMenuItems(actions: superset, isSuperset: true)
        Button(action: onUngroup) {
            Label("Ungroup Superset", systemImage: "square.split.1x2")
        }
    }

    // MARK: - Derived

    /// Rounds are shared: the most any slot has, and setting it sets them all.
    private var rounds: Int {
        slots.map(\.targetSets).max() ?? 0
    }

    private var roundsBinding: Binding<Int> {
        Binding(
            get: { rounds },
            set: { newValue in
                for slot in slots { slot.targetSets = newValue }
            }
        )
    }

    private func repsBinding(for slot: PlanExercise) -> Binding<Int> {
        Binding(get: { slot.targetReps }, set: { slot.targetReps = $0 })
    }

    private var chainItems: [SupersetChainItem] {
        slots.enumerated().map { index, slot in
            SupersetChainItem(
                id: slot.persistentModelID,
                letter: Supersets.letter(for: index),
                name: name(of: slot),
                category: slot.exercise?.category,
                detail: "× \(slot.targetReps)"
            )
        }
    }

    private func name(of slot: PlanExercise) -> String {
        slot.exercise?.name ?? "Exercise"
    }
}

#Preview {
    struct Demo: View {
        @State private var isExpanded = true
        var body: some View {
            List {
                PlanSupersetRow(
                    slots: SampleData.plan.orderedDays[1].orderedExercises,
                    isExpanded: $isExpanded,
                    onRemoveFromSuperset: { _ in },
                    onDelete: { _ in },
                    onUngroup: {},
                    superset: .none
                )
            }
        }
    }
    return Demo()
        .modelContainer(SampleData.container)
}
