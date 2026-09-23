//
//  ExerciseEntryRows.swift
//  PLog
//
//  The rows for one exercise on the session screen: a header (tap to expand), then — while
//  expanded — one `SetRow` per set, an "Add Set" row and a "Last time" footnote. Everything
//  is a plain row in the enclosing List section so swipe-to-delete works per set, and only
//  one exercise (and one set within it) is open at a time, driven by the parent.
//

import SwiftUI
import SwiftData

struct ExerciseEntryRows: View {
    @State private var viewModel: ExerciseEntryViewModel

    /// Controlled by the parent so only one exercise is expanded at a time — see `DayDetailView`.
    @Binding var isExpanded: Bool
    /// The one set open for editing across the whole day; the parent owns it.
    @Binding var expandedSetID: PersistentIdentifier?
    /// Opens the exercise's history (presented by the parent, so it works from any stack).
    var onHistory: (Exercise) -> Void
    /// Removes this exercise from the day (the parent owns deletion).
    var onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    /// Context is passed in explicitly because `@Environment` isn't available during `init`,
    /// and the view model needs it to insert/delete sets.
    init(
        entry: ExerciseEntry,
        context: ModelContext,
        isExpanded: Binding<Bool>,
        expandedSetID: Binding<PersistentIdentifier?>,
        onHistory: @escaping (Exercise) -> Void,
        onDelete: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: ExerciseEntryViewModel(entry: entry, context: context))
        _isExpanded = isExpanded
        _expandedSetID = expandedSetID
        self.onHistory = onHistory
        self.onDelete = onDelete
    }

    private var entry: ExerciseEntry { viewModel.entry }

    var body: some View {
        Group {
            headerRow

            if isExpanded {
                ForEach(viewModel.sets) { set in
                    SetRow(set: set, trend: viewModel.trend(for: set), isExpanded: isSetExpanded(set))
                }
                .onDelete(perform: deleteSets)
                // These are child rows of the exercise; a reorder drag here must not act on
                // the exercise — only the header row (below) offers the move handle.
                .moveDisabled(true)

                addSetRow
                    .moveDisabled(true)

                if let lastTime = viewModel.lastTimeLabel {
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
            HStack {
                // Name/chip lead and the set summary trails — until accessibility sizes,
                // where side-by-side columns wrap into single words; then it all stacks.
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 6) {
                        nameAndChip
                        Text(setSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                } else {
                    nameAndChip
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("^[\(entry.sets.count) set](inflect: true)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if entry.topWeight > 0 {
                            Text("Top: \(WeightFormatter.string(entry.topWeight)) kg")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .padding(.vertical, 4)
        }
        // Keeps the List row highlight, but text resolves against the label color rather
        // than the accent tint the default button style applies to its label.
        .tint(.primary)
        .id(entry.persistentModelID)
        .accessibilityAddTraits(isExpanded ? [.isSelected] : [])
        .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to show sets")
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            if let exercise = entry.exercise {
                Button {
                    onHistory(exercise)
                } label: {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
                .tint(.indigo)
            }
        }
        .contextMenu {
            if let exercise = entry.exercise {
                Button {
                    onHistory(exercise)
                } label: {
                    Label("History", systemImage: "chart.xyaxis.line")
                }
            }
            Button(role: .destructive, action: onDelete) {
                Label("Remove from Day", systemImage: "trash")
            }
        }
    }

    private var nameAndChip: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.exerciseName)
                .font(.headline)
                .foregroundStyle(.primary)
            if let category = entry.exercise?.category {
                CategoryChip(category: category)
            }
        }
    }

    /// e.g. "3 sets · Top: 60 kg" — the stacked layout's one-line summary.
    private var setSummary: String {
        // Plain pluralisation: the `^[…](inflect:)` markup only works in a `Text` literal.
        var parts = ["\(entry.sets.count) \(entry.sets.count == 1 ? "set" : "sets")"]
        if entry.topWeight > 0 {
            parts.append("Top: \(WeightFormatter.string(entry.topWeight)) kg")
        }
        return parts.joined(separator: " · ")
    }

    private var addSetRow: some View {
        Button {
            withAnimation(.snappy) {
                let added = viewModel.addSet()
                expandedSetID = added.persistentModelID
            }
        } label: {
            Label("Add Set", systemImage: "plus.circle")
        }
    }

    // MARK: - Helpers

    private func isSetExpanded(_ set: SetEntry) -> Binding<Bool> {
        Binding(
            get: { expandedSetID == set.persistentModelID },
            set: { expanded in expandedSetID = expanded ? set.persistentModelID : nil }
        )
    }

    private func deleteSets(at offsets: IndexSet) {
        let sets = viewModel.sets
        for index in offsets {
            viewModel.removeSet(sets[index])
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
                        ExerciseEntryRows(
                            entry: SampleData.recentDay.orderedEntries.first!,
                            context: SampleData.context,
                            isExpanded: $isExpanded,
                            expandedSetID: $expandedSetID,
                            onHistory: { _ in },
                            onDelete: {}
                        )
                    }
                }
            }
            .modelContainer(SampleData.container)
        }
    }
    return Demo()
}
