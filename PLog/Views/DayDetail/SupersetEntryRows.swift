//
//  SupersetEntryRows.swift
//  PLog
//
//  A superset on the session screen, merged into one block: a header with the exercises
//  stacked on a chain (tap to expand), then — while expanded — the sets interleaved by
//  round, the order they're actually done in: Round 1 is A's first set, then B's, and so
//  on. Each exercise keeps its own `ExerciseEntryViewModel`, so set prefill, drops and
//  trends work exactly as they do for a plain exercise.
//

import SwiftUI
import SwiftData

struct SupersetEntryRows: View {
    @State private var viewModels: [ExerciseEntryViewModel]

    /// Controlled by the parent so only one block is expanded at a time — see `DayDetailView`.
    @Binding var isExpanded: Bool
    /// The one set open for editing across the whole day; the parent owns it.
    @Binding var expandedSetID: PersistentIdentifier?
    var onHistory: (Exercise) -> Void
    /// Moves one exercise out of the superset (the parent owns ordering).
    var onRemoveFromSuperset: (ExerciseEntry) -> Void
    /// Removes one exercise from the day.
    var onDelete: (ExerciseEntry) -> Void
    var onUngroup: () -> Void
    var superset: SupersetActions

    /// The parent gives this view a new identity whenever membership changes (see
    /// `SupersetBlock.id`), so building the view models once here is safe.
    init(
        entries: [ExerciseEntry],
        context: ModelContext,
        isExpanded: Binding<Bool>,
        expandedSetID: Binding<PersistentIdentifier?>,
        onHistory: @escaping (Exercise) -> Void,
        onRemoveFromSuperset: @escaping (ExerciseEntry) -> Void,
        onDelete: @escaping (ExerciseEntry) -> Void,
        onUngroup: @escaping () -> Void,
        superset: SupersetActions
    ) {
        _viewModels = State(initialValue: entries.map { ExerciseEntryViewModel(entry: $0, context: context) })
        _isExpanded = isExpanded
        _expandedSetID = expandedSetID
        self.onHistory = onHistory
        self.onRemoveFromSuperset = onRemoveFromSuperset
        self.onDelete = onDelete
        self.onUngroup = onUngroup
        self.superset = superset
    }

    /// One set's place in a round: which exercise it belongs to and that exercise's letter.
    private struct RoundItem: Identifiable {
        let set: SetEntry
        let model: ExerciseEntryViewModel
        let letter: String
        var id: PersistentIdentifier { self.set.persistentModelID }
    }

    var body: some View {
        Group {
            headerRow

            if isExpanded {
                let rounds = rounds
                ForEach(Array(rounds.enumerated()), id: \.offset) { index, items in
                    roundHeader(index + 1)
                        .moveDisabled(true)
                        .deleteDisabled(true)

                    ForEach(items) { item in
                        setRow(item)
                    }
                    .onDelete { offsets in deleteSets(offsets.map { items[$0] }) }
                    .moveDisabled(true)
                }

                addRoundRow
                    .moveDisabled(true)

                if let lastTime {
                    Label(lastTime, systemImage: "clock.arrow.circlepath")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .moveDisabled(true)
                }
            }
        }
    }

    // MARK: - Rows

    private var headerRow: some View {
        Button {
            withAnimation(.snappy) { isExpanded.toggle() }
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    SupersetTitle(rounds: roundCount)
                    SupersetChain(items: chainItems)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .padding(.top, 2)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        // Text resolves against the label colour, not the accent — see `ExerciseEntryRows`.
        .tint(.primary)
        .id(viewModels.first?.entry.persistentModelID)
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
        .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to show rounds")
        .supersetAccessibilityActions(superset, isSuperset: true)
        .accessibilityAction(named: "Ungroup Superset", onUngroup)
        // Not a delete: one swipe shouldn't take several exercises' sets with it.
        .swipeActions(edge: .trailing) {
            Button(action: onUngroup) {
                Label("Ungroup", systemImage: "square.split.1x2")
            }
            .tint(.gray)
        }
        .contextMenu {
            ForEach(Array(viewModels.enumerated()), id: \.element.entry.persistentModelID) { index, model in
                Menu {
                    if let exercise = model.entry.exercise {
                        Button {
                            onHistory(exercise)
                        } label: {
                            Label("History", systemImage: "chart.xyaxis.line")
                        }
                    }
                    Button {
                        onRemoveFromSuperset(model.entry)
                    } label: {
                        Label("Remove from Superset", systemImage: "minus.circle")
                    }
                    Button(role: .destructive) {
                        onDelete(model.entry)
                    } label: {
                        Label("Remove from Day", systemImage: "trash")
                    }
                } label: {
                    Label(model.exerciseName, systemImage: letterSymbol(index))
                }
            }
            Divider()
            SupersetMenuItems(actions: superset, isSuperset: true)
            Button(action: onUngroup) {
                Label("Ungroup Superset", systemImage: "square.split.1x2")
            }
        }
    }

    /// A small label over its round's sets rather than a full row: tight insets, no
    /// divider beneath it (the parent list lowers its minimum row height to allow this).
    private func roundHeader(_ number: Int) -> some View {
        Text("Round \(number)")
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .listRowInsets(EdgeInsets(top: 14, leading: 20, bottom: 2, trailing: 20))
            .listRowSeparator(.hidden, edges: .bottom)
    }

    private func setRow(_ item: RoundItem) -> some View {
        let model = item.model
        let set = item.set
        return SetRow(
            set: set,
            title: set.isDrop ? model.title(for: set) : model.exerciseName,
            badge: set.isDrop ? nil : item.letter,
            trend: model.trend(for: set),
            isExpanded: isSetExpanded(set),
            onAddDrop: {
                withAnimation(.snappy) {
                    expandedSetID = model.addDrop(after: set).persistentModelID
                }
            },
            onToggleDrop: set.isDrop || model.canConvertToDrop(set)
                ? { withAnimation(.snappy) { model.toggleDrop(set) } }
                : nil
        )
    }

    /// One more set of every exercise — a superset grows a round at a time.
    private var addRoundRow: some View {
        Button {
            withAnimation(.snappy) {
                let added = viewModels.map { $0.addSet() }
                expandedSetID = added.first?.persistentModelID
            }
        } label: {
            Label("Add Round", systemImage: "plus.circle")
        }
    }

    // MARK: - Derived

    /// Round *n* is each exercise's working set *n* followed by its drops, in A, B… order.
    /// Exercises with fewer sets simply sit out the later rounds.
    private var rounds: [[RoundItem]] {
        let groups = viewModels.map(\.entry.setGroups)
        let count = groups.map(\.count).max() ?? 0
        return (0..<count).map { round in
            viewModels.indices.flatMap { index -> [RoundItem] in
                guard groups[index].indices.contains(round) else { return [] }
                return groups[index][round].map { set in
                    RoundItem(set: set, model: viewModels[index], letter: Supersets.letter(for: index))
                }
            }
        }
    }

    private var roundCount: Int {
        viewModels.map(\.entry.workingSets.count).max() ?? 0
    }

    private var chainItems: [SupersetChainItem] {
        viewModels.enumerated().map { index, model in
            SupersetChainItem(
                id: model.entry.persistentModelID,
                letter: Supersets.letter(for: index),
                name: model.exerciseName,
                category: model.entry.exercise?.category,
                detail: model.entry.topWeight > 0 ? "Top: \(WeightFormatter.string(model.entry.topWeight)) kg" : nil
            )
        }
    }

    /// e.g. "Last time: A 60 kg × 8 · B 50 kg × 10".
    private var lastTime: String? {
        let parts = viewModels.enumerated().compactMap { index, model -> String? in
            guard let previous = model.previousTopSet, previous.reps > 0 else { return nil }
            return "\(Supersets.letter(for: index)) \(WeightFormatter.string(previous.weight)) kg × \(previous.reps)"
        }
        return parts.isEmpty ? nil : "Last time: " + parts.joined(separator: " · ")
    }

    /// SF Symbols has a circled glyph for each letter; past Z, a plain circle.
    private func letterSymbol(_ index: Int) -> String {
        index < 26 ? "\(Supersets.letter(for: index).lowercased()).circle" : "circle"
    }

    private func isSetExpanded(_ set: SetEntry) -> Binding<Bool> {
        Binding(
            get: { expandedSetID == set.persistentModelID },
            set: { expanded in expandedSetID = expanded ? set.persistentModelID : nil }
        )
    }

    private func deleteSets(_ items: [RoundItem]) {
        for model in viewModels {
            let mine = items.filter { $0.model === model }.map(\.set)
            if !mine.isEmpty {
                model.removeSets(mine)
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State private var isExpanded = true
        @State private var expandedSetID: PersistentIdentifier?
        var body: some View {
            NavigationStack {
                List {
                    Section("Exercises") {
                        SupersetEntryRows(
                            entries: SampleData.recentDay.orderedEntries,
                            context: SampleData.context,
                            isExpanded: $isExpanded,
                            expandedSetID: $expandedSetID,
                            onHistory: { _ in },
                            onRemoveFromSuperset: { _ in },
                            onDelete: { _ in },
                            onUngroup: {},
                            superset: .none
                        )
                    }
                }
            }
            .modelContainer(SampleData.container)
        }
    }
    return Demo()
}
