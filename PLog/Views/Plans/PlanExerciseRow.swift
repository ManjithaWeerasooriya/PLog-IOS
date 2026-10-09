//
//  PlanExerciseRow.swift
//  PLog
//
//  One exercise slot in a day template: a `DisclosureGroup` whose label shows the "3 × 8"
//  summary and whose content is the target sets × reps steppers — the same system
//  expand/collapse as `SetRow`, expansion controlled by the parent so only one slot is
//  open at a time.
//

import SwiftUI
import SwiftData

struct PlanExerciseRow: View {
    /// `@Bindable` gives the steppers two-way bindings straight into the model.
    @Bindable var planExercise: PlanExercise
    /// Controlled by the parent so only one slot is expanded at a time (accordion-style) —
    /// see `PlanDayDetailView`.
    @Binding var isExpanded: Bool
    /// Ways to make this slot part of a superset — the parent sees its neighbours.
    var superset: SupersetActions = .none

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Side by side, stacked only at accessibility type sizes — see `SetRow` for why
            // this isn't a `ViewThatFits`.
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 16) { steppers }
                } else {
                    HStack(alignment: .top, spacing: 16) { steppers }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // The steppers are a child row of the slot; swipes and reorder drags there must
            // not act on the slot.
            .deleteDisabled(true)
            .moveDisabled(true)
        } label: {
            header
                // On the label only: a long-press on the steppers is hold-to-repeat.
                .contextMenu { SupersetMenuItems(actions: superset) }
                .supersetAccessibilityActions(superset)
        }
        .accessibilityHint("Double-tap to edit target sets and reps")
    }

    @ViewBuilder
    private var steppers: some View {
        NumberStepper(title: "Sets", intValue: $planExercise.targetSets, range: 1...20)
        NumberStepper(title: "Reps", intValue: $planExercise.targetReps, range: 1...100)
    }

    private var header: some View {
        HStack {
            // Stacked at accessibility sizes so the name doesn't wrap word by word.
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 6) {
                    nameAndChip
                    targets
                }
                Spacer()
            } else {
                nameAndChip
                Spacer()
                targets
            }
        }
        .padding(.vertical, 4)
    }

    private var nameAndChip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(planExercise.exercise?.name ?? "Exercise")
                .font(.headline)
            if let category = planExercise.exercise?.category {
                CategoryChip(category: category)
            }
        }
    }

    private var targets: some View {
        Text("\(planExercise.targetSets) × \(planExercise.targetReps)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
    }
}

#Preview {
    struct Demo: View {
        @State private var isExpanded = true
        var body: some View {
            List {
                PlanExerciseRow(
                    planExercise: SampleData.pushDay.orderedExercises.first!,
                    isExpanded: $isExpanded
                )
            }
        }
    }
    return Demo()
        .modelContainer(SampleData.container)
}
