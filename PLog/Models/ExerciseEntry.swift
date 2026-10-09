//
//  ExerciseEntry.swift
//  PLog
//
//  One exercise as performed on one `WorkoutDay` — the join between the reusable
//  `Exercise` and a specific session, holding that day's sets.
//

import Foundation
import SwiftData

@Model
final class ExerciseEntry {
    /// The master-list exercise this entry logs. Optional so the entry survives if the
    /// master `Exercise` is ever deleted (relationship nullifies rather than cascades).
    var exercise: Exercise?

    /// The session this entry belongs to. Inverse of `WorkoutDay.entries`.
    var workoutDay: WorkoutDay?

    /// Position within the day's exercise list (for stable ordering).
    var order: Int

    /// Shared by adjacent entries done as a superset (see `Supersets`); `nil` otherwise.
    var supersetID: UUID?

    /// The sets performed for this exercise on this day.
    ///
    /// Cascade delete: removing the entry removes its sets. Inverse on `SetEntry.entry`.
    @Relationship(deleteRule: .cascade, inverse: \SetEntry.entry)
    var sets: [SetEntry] = []

    init(
        exercise: Exercise? = nil,
        workoutDay: WorkoutDay? = nil,
        order: Int = 0,
        supersetID: UUID? = nil
    ) {
        self.exercise = exercise
        self.workoutDay = workoutDay
        self.order = order
        self.supersetID = supersetID
    }

    /// Sets in performed order.
    var orderedSets: [SetEntry] {
        sets.sorted { $0.setNumber < $1.setNumber }
    }

    /// Each working set followed by its drop sets, in performed order. A drop with no working
    /// set before it (only reachable through odd imported data) starts a group of its own.
    var setGroups: [[SetEntry]] {
        orderedSets.reduce(into: []) { groups, set in
            if set.isDrop, !groups.isEmpty {
                groups[groups.count - 1].append(set)
            } else {
                groups.append([set])
            }
        }
    }

    /// The numbered sets — drops are continuations of a set, not sets of their own, so they
    /// don't count toward "3 sets" or take part in set-by-set comparison.
    var workingSets: [SetEntry] {
        setGroups.compactMap(\.first)
    }

    /// The heaviest weight lifted across all sets in this entry.
    var topWeight: Double {
        sets.map(\.weight).max() ?? 0
    }

    /// Total volume (Σ weight × reps) — a useful single-number progress signal.
    var totalVolume: Double {
        sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }
}
