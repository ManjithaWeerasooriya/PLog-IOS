//
//  WorkoutStats.swift
//  PLog
//
//  Read-only aggregations over logged sessions for the Analytics tab: volume per day/week,
//  sessions per week, muscle-group split, streaks, best lifts and regressions. Pure functions
//  over the `@Query` results so the view stays a thin layout layer.
//

import Foundation
import SwiftData

enum WorkoutStats {
    struct DailyVolume: Identifiable {
        let date: Date
        let volume: Double
        var id: Date { date }
    }

    struct WeekSummary: Identifiable {
        /// Start of the week, per the calendar's first weekday.
        let weekStart: Date
        let sessions: Int
        let sets: Int
        let volume: Double
        var id: Date { weekStart }
    }

    struct MuscleGroupShare: Identifiable {
        let group: MuscleGroup
        let sets: Int
        var id: MuscleGroup { group }
    }

    struct ExerciseBest: Identifiable {
        let exercise: Exercise
        /// Best estimated 1RM across every logged session.
        let estimatedOneRepMax: Double
        /// Direction of the most recent session versus the one before it.
        let trend: ProgressTrend
        var id: PersistentIdentifier { exercise.persistentModelID }
    }

    /// An exercise's latest session against the one before it, on each session's top set.
    struct SessionComparison: Identifiable {
        let exercise: Exercise
        let latest: SetSnapshot
        let previous: SetSnapshot
        let latestDate: Date

        var trend: ProgressTrend {
            ProgressiveOverload.trend(current: latest, previous: previous)
        }

        /// Estimated 1RM change in kg; negative is a drop.
        var change: Double {
            latest.estimatedOneRepMax - previous.estimatedOneRepMax
        }

        var id: PersistentIdentifier { exercise.persistentModelID }
    }

    // MARK: - Per-session totals

    static func volume(of day: WorkoutDay) -> Double {
        day.entries.reduce(0) { $0 + $1.totalVolume }
    }

    static func setCount(of day: WorkoutDay) -> Int {
        day.entries.reduce(0) { $0 + $1.workingSets.count }
    }

    /// Sessions dated within `[start, end)`.
    static func workouts(_ workouts: [WorkoutDay], from start: Date, before end: Date) -> [WorkoutDay] {
        workouts.filter { $0.date >= start && $0.date < end }
    }

    // MARK: - Time series

    /// Volume for each of the last `count` calendar days ending today, oldest first. Days
    /// with no session are included as zero so a bar chart keeps a fixed width.
    static func dailyVolumes(
        workouts: [WorkoutDay],
        days count: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyVolume] {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }
        return (0..<count).reversed().compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: todayStart) else { return nil }
            let volume = (byDay[date] ?? []).reduce(0) { $0 + self.volume(of: $1) }
            return DailyVolume(date: date, volume: volume)
        }
    }

    /// One summary per week for the last `count` weeks ending with the current one, oldest
    /// first. Weeks with no session are included as zeros.
    static func weeklySummaries(
        workouts: [WorkoutDay],
        weeks count: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [WeekSummary] {
        guard let thisWeek = weekStart(of: today, calendar: calendar) else { return [] }
        let byWeek = Dictionary(grouping: workouts) { weekStart(of: $0.date, calendar: calendar) ?? $0.date }
        return (0..<count).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -back, to: thisWeek) else { return nil }
            let sessions = byWeek[start] ?? []
            return WeekSummary(
                weekStart: start,
                sessions: sessions.count,
                sets: sessions.reduce(0) { $0 + setCount(of: $1) },
                volume: sessions.reduce(0) { $0 + volume(of: $1) }
            )
        }
    }

    /// Sets per muscle group across the given sessions, largest first. Entries whose
    /// exercise was deleted from the library have no category and are skipped.
    static func muscleGroupSplit(workouts: [WorkoutDay]) -> [MuscleGroupShare] {
        var counts: [MuscleGroup: Int] = [:]
        for day in workouts {
            for entry in day.entries {
                guard let group = entry.exercise?.category else { continue }
                counts[group, default: 0] += entry.workingSets.count
            }
        }
        return counts
            .filter { $0.value > 0 }
            .map { MuscleGroupShare(group: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    /// Consecutive weeks with at least one session, counting back from this week. An empty
    /// current week doesn't break the streak — it isn't over yet — so the count starts from
    /// last week in that case.
    static func weekStreak(
        workouts: [WorkoutDay],
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        guard var cursor = weekStart(of: today, calendar: calendar) else { return 0 }
        let trainedWeeks = Set(workouts.compactMap { weekStart(of: $0.date, calendar: calendar) })
        if !trainedWeeks.contains(cursor) {
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var streak = 0
        while trainedWeeks.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The exercises with the highest best-ever estimated 1RM, strongest first. Trend
    /// compares the top set of the last two sessions the same way the set editor does.
    static func bestLifts(exercises: [Exercise], limit: Int = 5) -> [ExerciseBest] {
        exercises
            .compactMap { exercise -> ExerciseBest? in
                let points = WorkoutHistory.historyPoints(for: exercise)
                guard let best = points.map(\.estimatedOneRepMax).max(), best > 0 else { return nil }
                let trend = lastSessionComparison(for: exercise, points: points)?.trend ?? .none
                return ExerciseBest(exercise: exercise, estimatedOneRepMax: best, trend: trend)
            }
            .sorted { $0.estimatedOneRepMax > $1.estimatedOneRepMax }
            .prefix(limit)
            .map { $0 }
    }

    /// The last two sessions' top sets, or `nil` with fewer than two sessions. The one place
    /// Best Lifts' arrow and the Regressing list get their answer, so they can't disagree.
    static func lastSessionComparison(
        for exercise: Exercise,
        points: [ExerciseHistoryPoint]? = nil
    ) -> SessionComparison? {
        let points = points ?? WorkoutHistory.historyPoints(for: exercise)
        guard points.count >= 2 else { return nil }
        let last = points[points.count - 1]
        let previous = points[points.count - 2]
        return SessionComparison(
            exercise: exercise,
            latest: SetSnapshot(weight: last.topWeight, reps: last.topSetReps),
            previous: SetSnapshot(weight: previous.topWeight, reps: previous.topSetReps),
            latestDate: last.date
        )
    }

    /// Exercises whose latest session's estimated 1RM fell below the session before,
    /// biggest relative drop first.
    static func regressingExercises(exercises: [Exercise]) -> [SessionComparison] {
        exercises
            .compactMap { lastSessionComparison(for: $0) }
            .filter { $0.trend == .regressed }
            .sorted { lhs, rhs in
                relativeChange(lhs) < relativeChange(rhs)
            }
    }

    private static func relativeChange(_ comparison: SessionComparison) -> Double {
        comparison.change / max(comparison.previous.estimatedOneRepMax, 1)
    }

    /// Percentage change from `previous` to `current`; `nil` when there's no baseline.
    static func percentChange(from previous: Double, to current: Double) -> Double? {
        guard previous > 0 else { return nil }
        return (current - previous) / previous * 100
    }

    static func weekStart(of date: Date, calendar: Calendar = .current) -> Date? {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
    }
}
