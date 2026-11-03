//
//  WorkoutHistory.swift
//  PLog
//
//  Read-only helpers for pulling an exercise's history out of the object graph —
//  used for prefilling the entry form, the "last time" hints, and the history charts.
//

import Foundation
import SwiftData

/// A single point on an exercise's progress timeline (one logged session).
struct ExerciseHistoryPoint: Identifiable {
    let id: PersistentIdentifier
    let date: Date
    /// Heaviest weight of the session for this exercise.
    let topWeight: Double
    /// Reps performed on that top set.
    let topSetReps: Int
    /// Total volume (Σ weight × reps) for the session.
    let totalVolume: Double
    /// Best estimated 1RM across the session's sets.
    let estimatedOneRepMax: Double
}

enum WorkoutHistory {
    /// The most recent logged entry for `exercise`, optionally excluding the one currently
    /// being edited. Drives prefill and the "Last time" hint.
    static func previousEntry(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil
    ) -> ExerciseEntry? {
        // Newest first by date, then the first with sets — so only the newest entries' sets are
        // read, not every past session's (that read is the slow part with a long history).
        exercise.entries
            .compactMap { entry in
                entry === current ? nil : entry.workoutDay.map { (entry: entry, date: $0.date) }
            }
            .sorted { $0.date > $1.date }
            .first { !$0.entry.sets.isEmpty }?
            .entry
    }

    /// A snapshot of the top set from the previous session, for prefilling / comparison.
    static func previousTopSet(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil
    ) -> SetSnapshot? {
        guard let entry = previousEntry(for: exercise, excluding: current) else { return nil }
        guard let top = entry.sets.max(by: { $0.weight < $1.weight }) else { return nil }
        return SetSnapshot(weight: top.weight, reps: top.reps)
    }

    /// The previous session's working sets in performed order, for set-by-set comparison and
    /// prefill (set *n* this time vs. set *n* last time). Drop sets are left out so they don't
    /// shift the numbering. Empty when there's no previous session.
    static func previousSets(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil
    ) -> [SetSnapshot] {
        previousSetGroups(for: exercise, excluding: current).compactMap(\.first)
    }

    /// The previous session's sets grouped as `ExerciseEntry.setGroups` — each working set
    /// followed by its drops — so a drop is compared with the same drop last time.
    static func previousSetGroups(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil
    ) -> [[SetSnapshot]] {
        guard let entry = previousEntry(for: exercise, excluding: current) else { return [] }
        return entry.setGroups.map { group in
            group.map { SetSnapshot(weight: $0.weight, reps: $0.reps) }
        }
    }

    /// Chronological progress points for charting, oldest → newest.
    static func historyPoints(for exercise: Exercise) -> [ExerciseHistoryPoint] {
        exercise.entries
            .filter { $0.workoutDay != nil && !$0.sets.isEmpty }
            .sorted { ($0.workoutDay?.date ?? .distantPast) < ($1.workoutDay?.date ?? .distantPast) }
            .map { ExerciseHistoryPoint(SessionRecord.Entry($0), date: $0.workoutDay?.date ?? .now) }
    }
}
