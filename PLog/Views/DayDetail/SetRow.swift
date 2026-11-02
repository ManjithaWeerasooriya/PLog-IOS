//
//  SetRow.swift
//  PLog
//
//  One set on the session screen: a `DisclosureGroup` whose label is the one-line summary
//  (set number — or "Drop", indented under its set — trend badge, weight × reps) and whose
//  content is the weight and reps steppers. Using the system group means the expand/collapse motion, chevron and row
//  insertion are the platform's own — the same as subtasks in Reminders. Edits bind
//  straight into the model; there's no separate save step.
//

import SwiftUI
import SwiftData

struct SetRow: View {
    /// `@Bindable` gives the steppers two-way bindings into the SwiftData model.
    @Bindable var set: SetEntry
    /// "Set 2" or "Drop" — numbering skips drops, so the parent works it out. In a
    /// superset's rounds it's the exercise name instead.
    let title: String
    /// The exercise's superset letter, shown as a `SupersetBadge` before the title.
    var badge: String? = nil
    let trend: ProgressTrend
    /// Controlled by the parent so only one set is expanded at a time (accordion-style) —
    /// see `DayDetailView.expandedSetID`.
    @Binding var isExpanded: Bool
    /// Adds a drop set after this set (and any drops it already has).
    var onAddDrop: () -> Void = {}
    /// Flips this row between working set and drop; `nil` when that isn't allowed.
    var onToggleDrop: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            // Side by side, stacked only at accessibility type sizes. Not `ViewThatFits`:
            // it judges by *ideal* width and ignores the number's `minimumScaleFactor`,
            // so a wider value like 102.5 silently tipped the pair into the stack.
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(spacing: 16) { steppers }
                } else {
                    HStack(alignment: .top, spacing: 16) { steppers }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            // The steppers are a child row of the set; a swipe there must not delete the set.
            .deleteDisabled(true)
        } label: {
            summary
                // On the label only: a long-press on the steppers is hold-to-repeat.
                .contextMenu { dropActions }
                .accessibilityAction(named: "Add Drop Set", onAddDrop)
        }
        .accessibilityHint("Double-tap to edit")
        // One tick the moment a set first beats last time — not on every step after.
        .sensoryFeedback(.success, trigger: trend == .improved) { wasImproved, isImproved in
            !wasImproved && isImproved
        }
    }

    @ViewBuilder
    private var steppers: some View {
        NumberStepper(title: "Weight", value: $set.weight, step: 2.5, range: 0...500, unit: "kg")
        NumberStepper(title: "Reps", intValue: $set.reps, range: 0...100)
    }

    @ViewBuilder
    private var dropActions: some View {
        Button(action: onAddDrop) {
            Label("Add Drop Set", systemImage: "arrow.turn.down.right")
        }
        if let onToggleDrop {
            Button(action: onToggleDrop) {
                if set.isDrop {
                    Label("Make Working Set", systemImage: "arrow.uturn.left")
                } else {
                    Label("Make Drop Set", systemImage: "arrow.turn.down.right")
                }
            }
        }
    }

    private var summary: some View {
        HStack {
            if typeSize.isAccessibilitySize {
                // Stacked at accessibility sizes so the numbers don't wrap word by word.
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        setLabel
                        TrendBadge(trend: trend)
                    }
                    numbers
                }
                Spacer(minLength: 8)
            } else {
                setLabel
                TrendBadge(trend: trend)
                Spacer(minLength: 8)
                numbers
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var setLabel: some View {
        if set.isDrop {
            // Indented with a turn arrow so it reads as part of the set above.
            Label(title, systemImage: "arrow.turn.down.right")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
        } else {
            HStack(spacing: 8) {
                if let badge {
                    SupersetBadge(letter: badge)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var numbers: some View {
        Text("\(WeightFormatter.string(set.weight)) kg × \(set.reps)")
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
                SetRow(
                    set: SetEntry(setNumber: 1, weight: 62.5, reps: 8),
                    title: "Set 1",
                    trend: .improved,
                    isExpanded: $isExpanded
                )
                SetRow(
                    set: SetEntry(setNumber: 2, weight: 50, reps: 8, isDrop: true),
                    title: "Drop",
                    trend: .none,
                    isExpanded: .constant(false)
                )
            }
        }
    }
    return Demo()
}
