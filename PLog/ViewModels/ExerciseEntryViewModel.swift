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
    /// What a set row shows beside the set's own numbers.
    struct SetContext {
        var trend: ProgressTrend = .none
        /// The same set last session (set *n*, or the same drop), when there was one.
        var previous: SetSnapshot?
        /// This set is the exercise's best ever, by estimated 1RM.
        var isRecord = false
    }

    /// The entry being edited. Its `SetEntry` objects are edited in place by the steppers.
    let entry: ExerciseEntry

    /// The top set from the previous session — the "Last time" hint, and the fallback
    /// comparison for a set the previous session didn't have.
    var previousTopSet: SetSnapshot? { previous.topSet }

    /// The previous session's sets as working-set groups (each set followed by its drops),
    /// so set *n* is graded against set *n* and a drop against the same drop last time.
    var previousGroups: [[SetSnapshot]] { previous.groups }

    /// Last session, looked up on first use rather than in `init`. The session screen
    /// re-runs every row's `init` on each redraw (expanding an exercise, adding one) and
    /// `@State` keeps only the first view model, so a lookup in `init` was repeated for
    /// view models that were thrown straight away.
    @ObservationIgnored
    private lazy var previous: (topSet: SetSnapshot?, groups: [[SetSnapshot]]) = {
        guard let exercise = entry.exercise else { return (nil, []) }
        return (
            WorkoutHistory.previousTopSet(for: exercise, excluding: entry),
            WorkoutHistory.previousSetGroups(for: exercise, excluding: entry)
        )
    }()

    /// The exercise's best estimated 1RM in every session before this one; 0 with no
    /// history. Lazy for the same reason as `previous`, and because it walks the exercise's
    /// whole history: only an expanded exercise asks for it.
    @ObservationIgnored
    private lazy var priorBest: Double = {
        guard let exercise = entry.exercise else { return 0 }
        return WorkoutHistory.bestEstimatedOneRepMax(for: exercise, before: entry)
    }()

    /// Sets that are following an edit: while the first weight is being entered into an
    /// exercise that has none, the untouched sets after it take the same weight. Plain
    /// state, not observed — it changes on every stepper tick.
    @ObservationIgnored
    private var followers: (source: PersistentIdentifier, sets: [SetEntry], lastChange: Date)?

    /// How long after the last change an edit still counts as the same one. Long enough for
    /// taps on a stepper, short enough that correcting a set later doesn't move the others.
    static let followWindow: TimeInterval = 3

    private let context: ModelContext

    init(entry: ExerciseEntry, context: ModelContext) {
        self.entry = entry
        self.context = context
    }

    /// Sets sorted for display.
    var sets: [SetEntry] { entry.orderedSets }

    var exerciseName: String { entry.exercise?.name ?? "Exercise" }

    /// Form cues or machine settings saved on the exercise, shown while it's being logged.
    var exerciseNotes: String? {
        guard let notes = entry.exercise?.notes.trimmingCharacters(in: .whitespacesAndNewlines),
              !notes.isEmpty else { return nil }
        return notes
    }

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
    func lastTimeLabel(unit: WeightUnit) -> String? {
        ProgressiveOverload.lastTimeLabel(for: previousTopSet, unit: unit)
    }

    // MARK: - Mutations

    /// Seeds a brand-new entry with one set prefilled from last time (or sensible defaults)
    /// so the user can immediately nudge the numbers up. Called once, when the exercise is
    /// added to the day — not on every view model creation, so an entry whose sets were all
    /// deleted stays empty rather than silently regrowing a set.
    static func prefill(_ entry: ExerciseEntry, in context: ModelContext, unit: WeightUnit = .current) {
        guard entry.sets.isEmpty else { return }
        let previous = entry.exercise.flatMap { WorkoutHistory.previousTopSet(for: $0, excluding: entry) }
        let seed = previous ?? SetSnapshot(weight: unit.emptyBar, reps: 10)
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
    func addSet(unit: WeightUnit = .current) -> SetEntry {
        let number = (sets.last?.setNumber ?? 0) + 1
        let seed = previousSnapshot(group: entry.setGroups.count, drop: 0)
            ?? entry.workingSets.last.map(snapshot)
            ?? previousTopSet
            ?? SetSnapshot(weight: unit.emptyBar, reps: 10)
        let next = SetEntry(setNumber: number, weight: seed.weight, reps: seed.reps)
        context.insert(next)
        entry.sets.append(next)
        context.saveLogged()
        return next
    }

    /// Adds a drop set to the end of `set`'s group (after any drops it already has). It's
    /// seeded from the same drop last session, otherwise about 20% lighter than the set it
    /// follows — a typical drop — at the same reps. Returns it so the caller can expand it.
    @discardableResult
    func addDrop(after set: SetEntry, unit: WeightUnit = .current) -> SetEntry {
        let groups = entry.setGroups
        let groupIndex = groups.firstIndex { group in group.contains { $0 === set } } ?? groups.count - 1
        let group = groups.indices.contains(groupIndex) ? groups[groupIndex] : [set]
        let last = group.last ?? set
        let seed = previousSnapshot(group: groupIndex, drop: group.count)
            ?? SetSnapshot(weight: unit.roundedToStep(last.weight * 0.8), reps: last.reps)

        // Make room straight after the group so the drop sits under its own set.
        let number = last.setNumber + 1
        for later in entry.sets where later.setNumber >= number {
            later.setNumber += 1
        }
        let drop = SetEntry(setNumber: number, weight: seed.weight, reps: seed.reps, isDrop: true)
        context.insert(drop)
        entry.sets.append(drop)
        context.saveLogged()
        return drop
    }

    /// Turns a working set into a drop of the set before it, or a drop back into a set.
    func toggleDrop(_ set: SetEntry) {
        guard set.isDrop || canConvertToDrop(set) else { return }
        set.isDrop.toggle()
        context.saveLogged()
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
        followers = nil
        for set in doomed where entry.sets.contains(where: { $0 === set }) {
            entry.sets.removeAll { $0 === set }
            context.delete(set)
        }
        for (index, remaining) in entry.orderedSets.enumerated() {
            remaining.setNumber = index + 1
        }
        context.saveLogged()
    }

    /// Carries a first weight down the exercise. A plan day logged for the first time opens
    /// with every set at 0; entering the weight on one set used to mean entering it again on
    /// each set after it. Now, when a working set's weight leaves 0, the later working sets
    /// still at 0 follow it for as long as that edit continues (a held stepper, or a typed
    /// value). A set that already has a weight is never touched, so last session's numbers
    /// and anything typed by hand stay as they are.
    func weightChanged(of set: SetEntry, from old: Double, to new: Double, at now: Date = .now) {
        guard !set.isDrop, old != new else { return }
        let id = set.persistentModelID
        if old == 0 {
            let later = entry.workingSets.drop { $0 !== set }.dropFirst().filter { $0.weight == 0 }
            followers = later.isEmpty ? nil : (id, Array(later), now)
        }
        guard let current = followers, current.source == id,
              now.timeIntervalSince(current.lastChange) <= Self.followWindow else {
            followers = nil
            return
        }
        for follower in current.sets where follower.weight == old {
            follower.weight = new
        }
        followers?.lastChange = now
    }

    // MARK: - Comparison

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

    /// Everything a set row shows about a set: its trend, the same set last time, and whether
    /// it's a personal record.
    func context(for set: SetEntry) -> SetContext {
        guard let position = position(of: set) else { return SetContext() }
        let previous = previousSnapshot(group: position.group, drop: position.drop)
        return SetContext(
            trend: ProgressiveOverload.trend(
                current: snapshot(set),
                previous: position.drop > 0 ? previous : previous ?? previousTopSet
            ),
            previous: previous,
            isRecord: set === recordSet
        )
    }

    /// The one set that beats every earlier session of this exercise: the best set of this
    /// entry by estimated 1RM, if it's above the previous best. One mark per exercise, not
    /// one per set, and none the first time an exercise is logged — there's nothing to beat.
    var recordSet: SetEntry? {
        guard priorBest > 0 else { return nil }
        let best = sets.max { snapshot($0).estimatedOneRepMax < snapshot($1).estimatedOneRepMax }
        guard let best, snapshot(best).estimatedOneRepMax > priorBest + 0.01 else { return nil }
        return best
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
}
