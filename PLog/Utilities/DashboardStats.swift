//
//  DashboardStats.swift
//  PLog
//
//  Every figure the Progress widgets show, worked out in one go from `DashboardData`. The
//  widgets render from this plain value instead of reading the models in their `body`:
//  a widget that read `set.weight` there was re-run by Observation on every stepper tap
//  on the session screen, even with the Progress tab out of sight (about 1.6 s of main-
//  thread work per tap with two years of history). `AnalyticsView` builds it outside
//  `body`, from cached `SessionRecord`s, and only when the data has actually changed —
//  see AGENT.md.
//

import Foundation
import SwiftData

struct DashboardStats {
    /// The active plan, flattened to what the plan card and the sessions chart show.
    struct PlanSummary {
        let name: String
        let dayCount: Int
        let nextDayName: String?
    }

    var workoutCount = 0
    var bodyWeightKg: Double?
    var plan: PlanSummary?
    var thisWeekSessions = 0
    var totalSets = 0
    var streak = 0
    var last7Days: [WorkoutStats.DailyVolume] = []
    var previous7Volume: Double = 0
    /// Keyed by every `AnalyticsRange`, so changing a card's range needs no recompute.
    var weekly: [AnalyticsRange: [WorkoutStats.WeekSummary]] = [:]
    /// Keyed by every `MuscleSplitPeriod` — the ranges plus this week.
    var muscleSplit: [MuscleSplitPeriod: [WorkoutStats.MuscleGroupShare]] = [:]
    var setsDone: [MuscleSplitPeriod: Int] = [:]
    /// Every logged exercise, strongest first: the Best Lifts card shows the top few and
    /// `BestLiftsView` ranks them all.
    var bestLifts: [WorkoutStats.ExerciseBest] = []
    var regressions: [WorkoutStats.SessionComparison] = []
    /// This month's cells for the small Activity card.
    var thisMonthCells: [CalendarDayCell?] = []
    /// This month and the two before it, oldest first, for the wide Activity card.
    var activityMonths: [ActivityMonth] = []
    /// Each exercise's progress points, shared by Best Lifts, Regressing and Exercise
    /// Progress so the history is walked once rather than once per widget.
    private var historyPoints: [PersistentIdentifier: [ExerciseHistoryPoint]] = [:]

    static let empty = DashboardStats()

    private init() {}

    /// Builds every figure from fresh records — for previews and the widget gallery. The
    /// dashboard itself passes cached ones (see `SessionRecordCache`).
    @MainActor
    init(data: DashboardData, today: Date = .now, calendar: Calendar = .current) {
        self.init(data: data, records: data.workouts.map(SessionRecord.init), today: today, calendar: calendar)
    }

    /// `records` are `data.workouts` as plain values, in the same order. Everything that
    /// needs a session's sets reads them from there; only dates, plans and the calendar
    /// cells come from the models.
    @MainActor
    init(data: DashboardData, records: [SessionRecord], today: Date = .now, calendar: Calendar = .current) {
        let workouts = data.workouts

        workoutCount = records.count
        bodyWeightKg = data.bodyWeightKg
        plan = data.plans.first(where: \.isActive).map { plan in
            PlanSummary(
                name: plan.name,
                dayCount: plan.days.count,
                nextDayName: WorkoutLogger.suggestedNextDay(in: plan)?.name
            )
        }

        thisWeekSessions = WorkoutStats.weeklySummaries(sessions: records, weeks: 1, today: today, calendar: calendar)
            .first?.sessions ?? 0
        totalSets = records.reduce(0) { $0 + $1.workingSets }
        streak = WorkoutStats.weekStreak(workouts: records, today: today, calendar: calendar)

        last7Days = WorkoutStats.dailyVolumes(sessions: records, days: 7, today: today, calendar: calendar)
        let todayStart = calendar.startOfDay(for: today)
        if let end = calendar.date(byAdding: .day, value: -6, to: todayStart),
           let start = calendar.date(byAdding: .day, value: -7, to: end) {
            previous7Volume = WorkoutStats.workouts(records, from: start, before: end)
                .reduce(0) { $0 + $1.volume }
        }

        for range in AnalyticsRange.allCases {
            weekly[range] = WorkoutStats.weeklySummaries(sessions: records, weeks: range.weeks, today: today, calendar: calendar)
        }
        for period in MuscleSplitPeriod.allCases {
            muscleSplit[period] = WorkoutStats.muscleGroupSplit(sessions: records, weeks: period.weeks, today: today, calendar: calendar)
            setsDone[period] = WorkoutStats.workingSetCount(sessions: records, weeks: period.weeks, today: today, calendar: calendar)
        }

        // Each exercise's points, oldest first — what `WorkoutHistory.historyPoints` gives,
        // without walking each exercise's entries through the models again.
        for record in records {
            for entry in record.entries where !entry.setIDs.isEmpty {
                guard let exerciseID = entry.exerciseID else { continue }
                historyPoints[exerciseID, default: []].append(ExerciseHistoryPoint(entry, date: record.date))
            }
        }
        for (id, points) in historyPoints {
            historyPoints[id] = points.sorted { $0.date < $1.date }
        }
        let points = historyPoints
        let lookup: (Exercise) -> [ExerciseHistoryPoint] = { points[$0.persistentModelID] ?? [] }
        bestLifts = WorkoutStats.bestLifts(exercises: data.exercises, limit: .max, points: lookup)
        regressions = WorkoutStats.regressingExercises(exercises: data.exercises, points: lookup)

        let historyStart = WorkoutCalendar.historyStart(workouts: workouts, plans: data.plans, calendar: calendar)
        let thisMonth = WorkoutCalendar.startOfMonth(today, calendar: calendar)
        thisMonthCells = WorkoutCalendar.monthCells(
            for: thisMonth,
            workouts: workouts,
            historyStart: historyStart,
            today: today,
            calendar: calendar
        )
        activityMonths = (0..<3).reversed().compactMap { back in
            guard let month = calendar.date(byAdding: .month, value: -back, to: thisMonth) else { return nil }
            let cells = back == 0 ? thisMonthCells : WorkoutCalendar.monthCells(
                for: month,
                workouts: workouts,
                historyStart: historyStart,
                today: today,
                calendar: calendar
            )
            return ActivityMonth(
                id: month,
                label: month.formatted(.dateTime.month(.abbreviated)),
                weeks: WorkoutCalendar.weeks(cells)
            )
        }
    }

    /// Every regressing exercise with its history and dip run, for the Regressing detail screen.
    var regressionDetails: [WorkoutStats.RegressionDetail] {
        WorkoutStats.regressionDetails(regressions) { points(for: $0) }
    }

    /// An exercise's progress points, oldest first; empty for one with no history.
    func points(for exercise: Exercise) -> [ExerciseHistoryPoint] {
        historyPoints[exercise.persistentModelID] ?? []
    }
}
