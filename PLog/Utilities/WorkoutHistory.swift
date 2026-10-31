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
    /// One hand or two that session — points are only comparable within one mode.
    let handMode: HandMode
}

enum WorkoutHistory {
    /// The most recent logged entry for `exercise` done with `handMode`, optionally excluding
    /// the one currently being edited. Drives prefill and the "Last time" hint. Hand mode
    /// defaults to `current`'s, then the exercise's usual one, so a one-hand session is never
    /// prefilled or graded from a two-hand one.
    static func previousEntry(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil,
        handMode: HandMode? = nil
    ) -> ExerciseEntry? {
        let mode = handMode ?? current?.handMode ?? exercise.defaultHandMode
        return exercise.entries
            .filter { entry in
                entry !== current && entry.workoutDay != nil && !entry.sets.isEmpty
                    && entry.handMode == mode
            }
            .sorted { lhs, rhs in
                (lhs.workoutDay?.date ?? .distantPast) > (rhs.workoutDay?.date ?? .distantPast)
            }
            .first
    }

    /// A snapshot of the top set from the previous session, for prefilling / comparison.
    static func previousTopSet(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil,
        handMode: HandMode? = nil
    ) -> SetSnapshot? {
        guard let entry = previousEntry(for: exercise, excluding: current, handMode: handMode) else { return nil }
        guard let top = entry.sets.max(by: { $0.weight < $1.weight }) else { return nil }
        return SetSnapshot(weight: top.weight, reps: top.reps)
    }

    /// The previous session's working sets in performed order, for set-by-set comparison and
    /// prefill (set *n* this time vs. set *n* last time). Drop sets are left out so they don't
    /// shift the numbering. Empty when there's no previous session.
    static func previousSets(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil,
        handMode: HandMode? = nil
    ) -> [SetSnapshot] {
        previousSetGroups(for: exercise, excluding: current, handMode: handMode).compactMap(\.first)
    }

    /// The previous session's sets grouped as `ExerciseEntry.setGroups` — each working set
    /// followed by its drops — so a drop is compared with the same drop last time.
    static func previousSetGroups(
        for exercise: Exercise,
        excluding current: ExerciseEntry? = nil,
        handMode: HandMode? = nil
    ) -> [[SetSnapshot]] {
        guard let entry = previousEntry(for: exercise, excluding: current, handMode: handMode) else { return [] }
        return entry.setGroups.map { group in
            group.map { SetSnapshot(weight: $0.weight, reps: $0.reps) }
        }
    }

    /// Chronological progress points for charting, oldest → newest; only `handMode`'s
    /// sessions when one is given.
    static func historyPoints(for exercise: Exercise, handMode: HandMode? = nil) -> [ExerciseHistoryPoint] {
        exercise.entries
            .filter { $0.workoutDay != nil && !$0.sets.isEmpty && (handMode == nil || $0.handMode == handMode) }
            .sorted { ($0.workoutDay?.date ?? .distantPast) < ($1.workoutDay?.date ?? .distantPast) }
            .map { entry in
                let topSet = entry.sets.max(by: { $0.weight < $1.weight })
                let bestE1RM = entry.sets
                    .map { SetSnapshot(weight: $0.weight, reps: $0.reps).estimatedOneRepMax }
                    .max() ?? 0
                return ExerciseHistoryPoint(
                    id: entry.persistentModelID,
                    date: entry.workoutDay?.date ?? .now,
                    topWeight: topSet?.weight ?? 0,
                    topSetReps: topSet?.reps ?? 0,
                    totalVolume: entry.totalVolume,
                    estimatedOneRepMax: bestE1RM,
                    handMode: entry.handMode
                )
            }
    }

    /// Points for a single-line chart: the sessions done the same way as the latest one, so a
    /// switch between one and two hands doesn't draw as a jump.
    static func chartPoints(for exercise: Exercise) -> [ExerciseHistoryPoint] {
        let points = historyPoints(for: exercise)
        guard let latest = points.last?.handMode else { return points }
        return points.filter { $0.handMode == latest }
    }

    /// The hand modes this exercise has been logged with, two hands first.
    static func loggedHandModes(for exercise: Exercise) -> [HandMode] {
        let used = Set(exercise.entries.filter { $0.workoutDay != nil && !$0.sets.isEmpty }.map(\.handMode))
        return HandMode.allCases.filter(used.contains)
    }
}
