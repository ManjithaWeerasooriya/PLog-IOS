//
//  ExerciseEntryViewModel.swift
//  PLog
//
//  Drives one exercise's inline set list on the session screen: adding/duplicating sets,
//  removing them, and classifying each set against the previous session for progressive
//  overload. Edits to individual sets bind straight into the `SetEntry` models (autosave).
//

import Foundation
import SwiftData

@MainActor
@Observable
final class ExerciseEntryViewModel {
    /// The entry being edited. Its `SetEntry` objects are edited in place by the steppers.
    let entry: ExerciseEntry

    /// The top set from the previous session — the "Last time" hint, and the fallback
    /// comparison for a set the previous session didn't have.
    let previousTopSet: SetSnapshot?

    /// The previous session's sets as working-set groups (each set followed by its drops),
    /// so set *n* is graded against set *n* and a drop against the same drop last time.
    let previousGroups: [[SetSnapshot]]

    private let context: ModelContext

    init(entry: ExerciseEntry, context: ModelContext) {
        self.entry = entry
        self.context = context
        self.previousTopSet = entry.exercise.flatMap {
            WorkoutHistory.previousTopSet(for: $0, excluding: entry)
        }
        self.previousGroups = entry.exercise.map {
            WorkoutHistory.previousSetGroups(for: $0, excluding: entry)
        } ?? []
    }

    /// Sets sorted for display.
    var sets: [SetEntry] { entry.orderedSets }

    var exerciseName: String { entry.exercise?.name ?? "Exercise" }

    /// "Set 2" for a working set — numbered among working sets only — or "Drop".
    func title(for set: SetEntry) -> String {
        guard let position = position(of: set) else { return "Set" }
        return position.drop > 0 ? "Drop" : "Set \(position.group + 1)"
    }

    /// The very first set can't be a drop — there's nothing before it to drop from.
    func canConvertToDrop(_ set: SetEntry) -> Bool {
        !set.isDrop && sets.first !== set
    }

    /// The inline hint string, e.g. "Last time: 62.5 kg × 8".
    var lastTimeLabel: String? {
        ProgressiveOverload.lastTimeLabel(for: previousTopSet)
    }

    // MARK: - Mutations

    /// Seeds a brand-new entry with one set prefilled from last time (or sensible defaults)
    /// so the user can immediately nudge the numbers up. Called once, when the exercise is
    /// added to the day — not on every view model creation, so an entry whose sets were all
    /// deleted stays empty rather than silently regrowing a set.
    static func prefill(_ entry: ExerciseEntry, in context: ModelContext) {
        guard entry.sets.isEmpty else { return }
        let previous = entry.exercise.flatMap { WorkoutHistory.previousTopSet(for: $0, excluding: entry) }
        let seed = previous ?? SetSnapshot(weight: 20, reps: 10)
        let first = SetEntry(setNumber: 1, weight: seed.weight, reps: seed.reps)
        context.insert(first)
        entry.sets.append(first)
    }

    /// Adds the next working set. It's seeded from the same-numbered set last session when
    /// there was one (so a planned back-off set comes in at its usual load), otherwise it
    /// duplicates the last working set (the "another set, same load" flow) — never a drop,
    /// whose reduced weight isn't what the next set starts at. Returns it so the caller can
    /// expand it.
    @discardableResult
    func addSet() -> SetEntry {
        let number = (sets.last?.setNumber ?? 0) + 1
        let seed = previousSnapshot(group: entry.setGroups.count, drop: 0)
            ?? entry.workingSets.last.map(snapshot)
            ?? previousTopSet
            ?? SetSnapshot(weight: 20, reps: 10)
        let next = SetEntry(setNumber: number, weight: seed.weight, reps: seed.reps)
        context.insert(next)
        entry.sets.append(next)
        try? context.save()
        return next
    }

    /// Adds a drop set to the end of `set`'s group (after any drops it already has). It's
    /// seeded from the same drop last session, otherwise about 20% lighter than the set it
    /// follows — a typical drop — at the same reps. Returns it so the caller can expand it.
    @discardableResult
    func addDrop(after set: SetEntry) -> SetEntry {
        let groups = entry.setGroups
        let groupIndex = groups.firstIndex { group in group.contains { $0 === set } } ?? groups.count - 1
        let group = groups.indices.contains(groupIndex) ? groups[groupIndex] : [set]
        let last = group.last ?? set
        let seed = previousSnapshot(group: groupIndex, drop: group.count)
            ?? SetSnapshot(weight: Self.dropWeight(from: last.weight), reps: last.reps)

        // Make room straight after the group so the drop sits under its own set.
        let number = last.setNumber + 1
        for later in entry.sets where later.setNumber >= number {
            later.setNumber += 1
        }
        let drop = SetEntry(setNumber: number, weight: seed.weight, reps: seed.reps, isDrop: true)
        context.insert(drop)
        entry.sets.append(drop)
        try? context.save()
        return drop
    }

    /// Turns a working set into a drop of the set before it, or a drop back into a set.
    func toggleDrop(_ set: SetEntry) {
        guard set.isDrop || canConvertToDrop(set) else { return }
        set.isDrop.toggle()
        try? context.save()
    }

    /// Removes sets and renumbers the remainder so `setNumber` stays 1-based and contiguous.
    /// Removing a working set takes its drops with it — they have nothing to belong to
    /// otherwise, the way deleting a reminder takes its subtasks.
    func removeSets(_ targets: [SetEntry]) {
        var doomed: [SetEntry] = []
        for group in entry.setGroups {
            for (index, set) in group.enumerated() where targets.contains(where: { $0 === set }) {
                doomed.append(contentsOf: index == 0 ? group : [set])
            }
        }
        for set in doomed where entry.sets.contains(where: { $0 === set }) {
            entry.sets.removeAll { $0 === set }
            context.delete(set)
        }
        for (index, remaining) in entry.orderedSets.enumerated() {
            remaining.setNumber = index + 1
        }
        try? context.save()
    }

    /// Progressive-overload classification for a set versus the **same-numbered** set last
    /// session — so a deliberate back-off third set isn't graded against your heaviest set
    /// and painted red. A set the previous session didn't have falls back to the top set.
    /// A drop is graded only against the same drop last time; with none, it has no trend.
    func trend(for set: SetEntry) -> ProgressTrend {
        guard let position = position(of: set) else { return .none }
        let previous = previousSnapshot(group: position.group, drop: position.drop)
        return ProgressiveOverload.trend(
            current: snapshot(set),
            previous: position.drop > 0 ? previous : previous ?? previousTopSet
        )
    }

    // MARK: - Helpers

    /// Where a set sits: its working-set group, and 0 for the working set or 1… for its drops.
    private func position(of set: SetEntry) -> (group: Int, drop: Int)? {
        for (groupIndex, group) in entry.setGroups.enumerated() {
            if let dropIndex = group.firstIndex(where: { $0 === set }) {
                return (groupIndex, dropIndex)
            }
        }
        return nil
    }

    private func previousSnapshot(group: Int, drop: Int) -> SetSnapshot? {
        guard previousGroups.indices.contains(group),
              previousGroups[group].indices.contains(drop) else { return nil }
        return previousGroups[group][drop]
    }

    private func snapshot(_ set: SetEntry) -> SetSnapshot {
        SetSnapshot(weight: set.weight, reps: set.reps)
    }

    /// 80% of `weight`, rounded to the nearest 2.5 kg plate step.
    private static func dropWeight(from weight: Double) -> Double {
        max(0, (weight * 0.8 / 2.5).rounded() * 2.5)
    }
}
