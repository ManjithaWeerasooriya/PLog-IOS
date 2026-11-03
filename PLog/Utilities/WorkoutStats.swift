//
//  WorkoutStats.swift
//  PLog
//
//  Read-only aggregations over logged sessions for the Analytics tab: volume per day/week,
//  sessions per week, muscle-group split, streaks, best lifts and regressions. Pure functions
//  over `SessionRecord`s (plain copies of the sessions, see `SessionRecordCache`) so the
//  view stays a thin layout layer.
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
        /// Weighted: whole sets from primary groups, halves from secondary ones.
        let sets: Double
        var id: MuscleGroup { group }
    }

    /// How much one working set counts toward a secondary muscle group.
    static let secondarySetWeight = 0.5

    /// "12" or "4.5" — a weighted set count with a decimal only when it has a half.
    static func setCountString(_ sets: Double) -> String {
        sets == sets.rounded() ? "\(Int(sets))" : String(format: "%.1f", sets)
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

    // MARK: - Date windows

    /// Sessions dated within `[start, end)`.
    static func workouts<Session: Dated>(_ workouts: [Session], from start: Date, before end: Date) -> [Session] {
        workouts.filter { $0.date >= start && $0.date < end }
    }

    // MARK: - Time series

    /// Volume for each of the last `count` calendar days ending today, oldest first. Days
    /// with no session are included as zero so a bar chart keeps a fixed width.
    static func dailyVolumes(
        sessions workouts: [SessionRecord],
        days count: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyVolume] {
        let todayStart = calendar.startOfDay(for: today)
        let byDay = Dictionary(grouping: workouts) { calendar.startOfDay(for: $0.date) }
        return (0..<count).reversed().compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: todayStart) else { return nil }
            let volume = (byDay[date] ?? []).reduce(0) { $0 + $1.volume }
            return DailyVolume(date: date, volume: volume)
        }
    }

    /// One summary per week for the last `count` weeks ending with the current one, oldest
    /// first. Weeks with no session are included as zeros.
    static func weeklySummaries(
        sessions workouts: [SessionRecord],
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
                sets: sessions.reduce(0) { $0 + $1.workingSets },
                volume: sessions.reduce(0) { $0 + $1.volume }
            )
        }
    }

    /// Sets per muscle group across the given sessions, largest first. A set counts in full
    /// for each of its exercise's primary groups and as `secondarySetWeight` for each
    /// secondary one, so the shares sum to more than the sets actually done. Entries whose
    /// exercise was deleted from the library have no groups and are skipped.
    static func muscleGroupSplit(sessions workouts: [SessionRecord]) -> [MuscleGroupShare] {
        var counts: [MuscleGroup: Double] = [:]
        for day in workouts {
            for entry in day.entries {
                let sets = Double(entry.workingSets)
                for group in entry.primaryMuscles {
                    counts[group, default: 0] += sets
                }
                for group in entry.secondaryMuscles {
                    counts[group, default: 0] += sets * secondarySetWeight
                }
            }
        }
        return counts
            .filter { $0.value > 0 }
            .map { MuscleGroupShare(group: $0.key, sets: $0.value) }
            .sorted { $0.sets > $1.sets }
    }

    /// Sets per muscle group over the last `weeks` weeks ending with the current one — the
    /// Muscle Groups widget and its detail screen both read this, so their totals agree.
    static func muscleGroupSplit(
        sessions: [SessionRecord],
        weeks: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [MuscleGroupShare] {
        muscleGroupSplit(sessions: self.workouts(sessions, inLastWeeks: weeks, today: today, calendar: calendar))
    }

    /// The same split straight from the models, for a screen without the dashboard's records.
    /// Only the sessions in range are read.
    static func muscleGroupSplit(
        workouts: [WorkoutDay],
        weeks: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [MuscleGroupShare] {
        muscleGroupSplit(
            sessions: self.workouts(workouts, inLastWeeks: weeks, today: today, calendar: calendar).map { SessionRecord($0) },
            weeks: weeks,
            today: today,
            calendar: calendar
        )
    }

    /// Working sets actually performed over the same window as `muscleGroupSplit(workouts:weeks:)`.
    /// This is the donut's centre figure: the split's shares are weighted (a secondary muscle
    /// gets half a set), so they sum to more than was done and can end in .5.
    static func workingSetCount(
        sessions: [SessionRecord],
        weeks: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        self.workouts(sessions, inLastWeeks: weeks, today: today, calendar: calendar)
            .reduce(0) { $0 + $1.workingSets }
    }

    /// The same count straight from the models; only the sessions in range are read.
    static func workingSetCount(
        workouts: [WorkoutDay],
        weeks: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        workingSetCount(
            sessions: self.workouts(workouts, inLastWeeks: weeks, today: today, calendar: calendar).map { SessionRecord($0) },
            weeks: weeks,
            today: today,
            calendar: calendar
        )
    }

    /// Sessions in the last `weeks` weeks, counting the current one.
    static func workouts<Session: Dated>(
        _ workouts: [Session],
        inLastWeeks weeks: Int,
        today: Date = .now,
        calendar: Calendar = .current
    ) -> [Session] {
        guard
            let thisWeek = weekStart(of: today, calendar: calendar),
            let start = calendar.date(byAdding: .weekOfYear, value: -(max(weeks, 1) - 1), to: thisWeek)
        else { return [] }
        return self.workouts(workouts, from: start, before: .distantFuture)
    }

    /// A whole set count for a headline: "744", "1,204", or "12K" from 10,000 up.
    static func compactCountString(_ count: Int) -> String {
        count >= 10_000
            ? count.formatted(.number.notation(.compactName))
            : count.formatted(.number.grouping(.automatic))
    }

    /// Consecutive weeks with at least one session, counting back from this week. An empty
    /// current week doesn't break the streak — it isn't over yet — so the count starts from
    /// last week in that case.
    static func weekStreak(
        workouts: [some Dated],
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
    /// `points` supplies each exercise's history; pass precomputed points to avoid walking
    /// the history again (see `DashboardStats`).
    static func bestLifts(
        exercises: [Exercise],
        limit: Int = 5,
        points pointsFor: ((Exercise) -> [ExerciseHistoryPoint])? = nil
    ) -> [ExerciseBest] {
        exercises
            .compactMap { exercise -> ExerciseBest? in
                let points = pointsFor?(exercise) ?? WorkoutHistory.historyPoints(for: exercise)
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
    static func regressingExercises(
        exercises: [Exercise],
        points pointsFor: ((Exercise) -> [ExerciseHistoryPoint])? = nil
    ) -> [SessionComparison] {
        exercises
            .compactMap { lastSessionComparison(for: $0, points: pointsFor?($0)) }
            .filter { $0.trend == .regressed }
            .sorted { lhs, rhs in
                relativeChange(lhs) < relativeChange(rhs)
            }
    }

    /// A regressing exercise as its detail screen shows it: the comparison, the history
    /// behind it, and whether the dip is a one-off or a run.
    struct RegressionDetail: Identifiable {
        let comparison: SessionComparison
        /// Oldest first, as `WorkoutHistory.historyPoints` gives them.
        let points: [ExerciseHistoryPoint]
        /// Sessions in a row that came in under the one before, counting back from the latest:
        /// 1 is a one-off dip, 3 is three sessions sliding.
        let consecutiveDips: Int

        var id: PersistentIdentifier { comparison.id }
        var exercise: Exercise { comparison.exercise }
        /// The session compared against — the one before the latest.
        var previousDate: Date? { points.count >= 2 ? points[points.count - 2].date : nil }
    }

    /// `regressions` (already in display order) with each exercise's points and dip run.
    static func regressionDetails(
        _ regressions: [SessionComparison],
        points pointsFor: (Exercise) -> [ExerciseHistoryPoint]
    ) -> [RegressionDetail] {
        regressions.map { comparison in
            let points = pointsFor(comparison.exercise)
            return RegressionDetail(
                comparison: comparison,
                points: points,
                consecutiveDips: consecutiveDips(in: points)
            )
        }
    }

    /// How many sessions in a row, counting back from the latest, came in under the session
    /// before — judged on top sets by `ProgressiveOverload.trend`, the same comparison the
    /// Regressing list and Best Lifts' arrows use. 0 when the latest didn't dip.
    static func consecutiveDips(in points: [ExerciseHistoryPoint]) -> Int {
        var dips = 0
        var index = points.count - 1
        while index > 0 {
            let latest = SetSnapshot(weight: points[index].topWeight, reps: points[index].topSetReps)
            let previous = SetSnapshot(weight: points[index - 1].topWeight, reps: points[index - 1].topSetReps)
            guard ProgressiveOverload.trend(current: latest, previous: previous) == .regressed else { break }
            dips += 1
            index -= 1
        }
        return dips
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

// MARK: - Hypertrophy volume

/// Weekly working-set targets per muscle group. The one place to change them.
enum HypertrophyTarget {
    /// At or above this many working sets a week, a muscle group gets enough volume to grow.
    static let minimumWeeklySets: Double = 10
    /// Above this, volume is flagged as high (likely more than can be recovered from).
    static let highWeeklySets: Double = 30

    enum Status {
        case below, met, high
    }

    /// Cardio, Full Body and Other aren't one muscle, so a per-muscle set target means nothing.
    static func applies(to group: MuscleGroup) -> Bool {
        group != .cardio && group != .fullBody && group != .other
    }

    static func status(weeklySets: Double) -> Status {
        if weeklySets > highWeeklySets { return .high }
        if weeklySets >= minimumWeeklySets { return .met }
        return .below
    }
}
