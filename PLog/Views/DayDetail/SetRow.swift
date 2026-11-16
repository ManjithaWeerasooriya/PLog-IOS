//
//  SetRow.swift
//  PLog
//
//  One set on the session screen: a `DisclosureGroup` whose label is the one-line summary
//  (set number — or "Drop", indented under its set — trend badge, weight × reps) and whose
//  content is the weight and reps steppers, the optional reps-in-reserve picker, and what
//  this set was last time. Using the system group means the expand/collapse motion, chevron
//  and row insertion are the platform's own — the same as subtasks in Reminders. Edits bind
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
    /// The set's trend, the same set last time, and whether it's a record.
    var context = ExerciseEntryViewModel.SetContext()
    /// Controlled by the parent so only one set is expanded at a time (accordion-style) —
    /// see `DayDetailView.expandedSetID`.
    @Binding var isExpanded: Bool
    /// Told about every weight edit (old, new) so a first weight can carry down the exercise.
    var onWeightChange: (Double, Double) -> Void = { _, _ in }
    /// Adds a drop set after this set (and any drops it already has).
    var onAddDrop: () -> Void = {}
    /// Flips this row between working set and drop; `nil` when that isn't allowed.
    var onToggleDrop: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.weightUnit) private var unit
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(EffortTracking.storageKey) private var tracksEffort = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 16) {
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
                if tracksEffort {
                    effortPicker
                }
                if let previous = context.previous, previous.reps > 0 {
                    Text(hint(for: previous))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
                .accessibilityAction(named: "Add Drop Set", onAddDrop)
        }
        .accessibilityHint("Double-tap to edit")
        // One tick the moment a set first beats last time — not on every step after.
        .sensoryFeedback(.success, trigger: context.trend == .improved) { wasImproved, isImproved in
            !wasImproved && isImproved
        }
        .sensoryFeedback(.success, trigger: context.isRecord) { wasRecord, isRecord in
            !wasRecord && isRecord
        }
    }

    @ViewBuilder
    private var steppers: some View {
        NumberStepper(title: "Weight", value: weight, step: unit.loadStep, range: 0...unit.maxLoad, unit: unit.symbol)
        NumberStepper(title: "Reps", intValue: $set.reps, range: 0...100)
    }

    /// Writes the weight and reports the change, so the parent can carry a first weight down.
    private var weight: Binding<Double> {
        Binding(
            get: { set.weight },
            set: { new in
                let old = set.weight
                set.weight = new
                onWeightChange(old, new)
            }
        )
    }

    /// How close to failure the set went. Optional and off by default (Settings); stored in
    /// the set's `rpe` as 10 − RIR.
    private var effortPicker: some View {
        VStack(spacing: 6) {
            Text("Reps in reserve")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .accessibilityHidden(true)
            Picker("Reps in reserve", selection: $set.repsInReserve) {
                Text("–").tag(Int?.none)
                    .accessibilityLabel("Not recorded")
                ForEach(EffortTracking.choices, id: \.self) { reps in
                    Text(EffortTracking.label(reps)).tag(Int?.some(reps))
                }
            }
            .pickerStyle(.segmented)
        }
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
                        badges
                    }
                    numbers
                }
                Spacer(minLength: 8)
            } else {
                setLabel
                badges
                Spacer(minLength: 8)
                numbers
            }
        }
        .padding(.vertical, 4)
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: context.isRecord)
    }

    @ViewBuilder
    private var badges: some View {
        TrendBadge(trend: context.trend)
        if context.isRecord {
            RecordBadge()
                // Never from nothing: a slight scale with the fade reads as arriving.
                .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
        }
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
        Text(numbersText)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .contentTransition(reduceMotion ? .identity : .numericText())
    }

    /// "60 kg × 8", with " · 2 RIR" when effort is tracked and recorded.
    private var numbersText: String {
        var text = "\(unit.string(set.weight)) × \(set.reps)"
        if tracksEffort, let reserve = set.repsInReserve {
            text += " · \(EffortTracking.label(reserve)) RIR"
        }
        return text
    }

    /// "Last time 60 kg × 8. Beat it with 60 × 9 or 62.5 × 7."
    private func hint(for previous: SetSnapshot) -> String {
        let last = "Last time \(ProgressiveOverload.setLabel(previous, unit: unit))"
        let targets = ProgressiveOverload.targets(toBeat: previous, step: unit.loadStep)
            .map { ProgressiveOverload.shortSetLabel($0) }
        guard !targets.isEmpty else { return "\(last)." }
        return "\(last). Beat it with \(targets.joined(separator: " or "))."
    }

    /// One sentence for VoiceOver in place of the row's separate fragments.
    private var accessibilitySummary: String {
        var parts = [badge.map { "\($0), \(title)" } ?? title]
        parts.append("\(WeightFormatter.string(set.weight)) \(unit.spokenName), \(set.reps) \(set.reps == 1 ? "rep" : "reps")")
        if tracksEffort, let reserve = set.repsInReserve {
            parts.append("\(EffortTracking.label(reserve)) reps in reserve")
        }
        if !context.trend.accessibilityLabel.isEmpty {
            parts.append(context.trend.accessibilityLabel)
        }
        if context.isRecord {
            parts.append("Personal record")
        }
        return parts.joined(separator: ", ")
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
                    context: .init(trend: .improved, previous: SetSnapshot(weight: 60, reps: 8), isRecord: true),
                    isExpanded: $isExpanded
                )
                SetRow(
                    set: SetEntry(setNumber: 2, weight: 50, reps: 8, isDrop: true),
                    title: "Drop",
                    isExpanded: .constant(false)
                )
            }
        }
    }
    return Demo()
}
