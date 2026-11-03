//
//  ProgressDetailTests.swift
//  PLogTests
//
//  The data behind Muscle Groups' "this week" filter and the Regressing detail screen:
//  which sessions "this week" takes (it follows the locale's first weekday), that the
//  choice survives the layout store and a JSON backup, how a dip run is counted, and that
//  the regression delta is the Epley e1RM difference the rest of the app uses.
//

import XCTest
import SwiftData
@testable import PLog

final class ProgressDetailTests: XCTestCase {
    // MARK: - This week

    /// Wednesday 4 Nov 2026, with sessions on the Sunday and Monday before it. A
    /// Monday-first week (most of Europe) holds only Monday's; a Sunday-first week (US) holds
    /// both.
    func testThisWeekFollowsTheLocalesFirstWeekday() throws {
        let context = try makeContext()
        let chest = Exercise(name: "Bench Press", category: .chest)
        context.insert(chest)
        log(chest, on: date(2026, 11, 1), sets: [(60, 8), (60, 8)], in: context)   // Sunday
        log(chest, on: date(2026, 11, 2), sets: [(62.5, 8)], in: context)          // Monday
        let records = try sessionRecords(context)
        let wednesday = date(2026, 11, 4)

        let mondayFirst = calendar(firstWeekday: 2)
        XCTAssertEqual(WorkoutStats.workingSetCount(sessions: records, weeks: MuscleSplitPeriod.thisWeek.weeks, today: wednesday, calendar: mondayFirst), 1)
        let mondaySplit = WorkoutStats.muscleGroupSplit(sessions: records, weeks: MuscleSplitPeriod.thisWeek.weeks, today: wednesday, calendar: mondayFirst)
        XCTAssertEqual(mondaySplit.map(\.group), [.chest])
        XCTAssertEqual(mondaySplit.first?.sets, 1)

        let sundayFirst = calendar(firstWeekday: 1)
        XCTAssertEqual(WorkoutStats.workingSetCount(sessions: records, weeks: MuscleSplitPeriod.thisWeek.weeks, today: wednesday, calendar: sundayFirst), 3)
    }

    /// Nothing logged since the week began: an empty split (the card's empty state), while
    /// a range still sees the older session.
    func testThisWeekIsEmptyWithoutSetsThisWeek() throws {
        let context = try makeContext()
        let chest = Exercise(name: "Bench Press", category: .chest)
        context.insert(chest)
        log(chest, on: date(2026, 10, 28), sets: [(60, 8)], in: context)
        let records = try sessionRecords(context)
        let wednesday = date(2026, 11, 4)
        let mondayFirst = calendar(firstWeekday: 2)

        XCTAssertTrue(WorkoutStats.muscleGroupSplit(sessions: records, weeks: 1, today: wednesday, calendar: mondayFirst).isEmpty)
        XCTAssertEqual(WorkoutStats.workingSetCount(sessions: records, weeks: 1, today: wednesday, calendar: mondayFirst), 0)
        XCTAssertEqual(WorkoutStats.workingSetCount(sessions: records, weeks: 8, today: wednesday, calendar: mondayFirst), 1)
    }

    /// "This week" is stored as `rangeWeeks` 1. Other kinds keep reading it as a range, and
    /// a stored range reads back as that range.
    func testMuscleSplitPeriodIsStoredOnTheWidget() {
        let widget = DashboardWidget(kind: .muscleSplit, range: .halfYear)
        XCTAssertEqual(widget.muscleSplitPeriod, .range(.halfYear))

        widget.muscleSplitPeriod = .thisWeek
        XCTAssertEqual(widget.rangeWeeks, 1)
        XCTAssertEqual(widget.muscleSplitPeriod, .thisWeek)
        XCTAssertEqual(widget.range, .twelveWeeks, "Anything reading it as a range gets the default")

        XCTAssertNil(MuscleSplitPeriod(weeks: 5))
        XCTAssertEqual(MuscleSplitPeriod(weeks: 8), .range(.eightWeeks))
    }

    /// A backup carries "this week" through export and restore; another widget's range is
    /// untouched.
    func testThisWeekSurvivesABackupRoundTrip() throws {
        let context = try makeContext()
        Dashboard.ensureExists(in: context)
        let dashboard = try XCTUnwrap(context.fetch(FetchDescriptor<Dashboard>()).first)
        let split = try XCTUnwrap(dashboard.widgets.first { $0.kind == .muscleSplit })
        split.muscleSplitPeriod = .thisWeek
        let weekly = try XCTUnwrap(dashboard.widgets.first { $0.kind == .weeklyVolume })
        weekly.range = .halfYear
        try context.save()

        let backup = try DataBackup.decode(DataBackup.export(from: context))
        let restoredContext = try makeContext()
        try DataBackup.restore(backup, into: restoredContext)
        let restored = try XCTUnwrap(restoredContext.fetch(FetchDescriptor<Dashboard>()).first)

        XCTAssertEqual(restored.widgets.first { $0.kind == .muscleSplit }?.muscleSplitPeriod, .thisWeek)
        XCTAssertEqual(restored.widgets.first { $0.kind == .weeklyVolume }?.range, .halfYear)
    }

    // MARK: - Regression details

    /// 100 → 105 → 100 → 95 kg at 5 reps: the last two sessions dipped, the one before rose.
    func testConsecutiveDipsCountsBackFromTheLatest() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", category: .chest)
        context.insert(bench)
        for (day, weight) in [(1, 100.0), (8, 105), (15, 100), (22, 95)] {
            log(bench, on: date(2026, 10, day), sets: [(weight, 5)], in: context)
        }
        let points = WorkoutHistory.historyPoints(for: bench)
        XCTAssertEqual(WorkoutStats.consecutiveDips(in: points), 2)

        // A matched session ends the run; an improved latest has none.
        XCTAssertEqual(WorkoutStats.consecutiveDips(in: Array(points.prefix(2))), 0)
        log(bench, on: date(2026, 10, 29), sets: [(95, 5)], in: context)
        XCTAssertEqual(WorkoutStats.consecutiveDips(in: WorkoutHistory.historyPoints(for: bench)), 0)
        XCTAssertEqual(WorkoutStats.consecutiveDips(in: []), 0)
    }

    /// The detail for a regressing exercise: the delta is the Epley e1RM difference of the two
    /// top sets, and it knows the session it was compared against.
    func testRegressionDetailsCarryDeltaDipsAndPreviousDate() throws {
        let context = try makeContext()
        let squat = Exercise(name: "Back Squat", category: .quads)
        let row = Exercise(name: "Barbell Row", category: .back)
        [squat, row].forEach(context.insert)
        log(squat, on: date(2026, 10, 1), sets: [(100, 5)], in: context)
        log(squat, on: date(2026, 10, 8), sets: [(110, 5), (90, 8)], in: context)
        log(squat, on: date(2026, 10, 15), sets: [(100, 6)], in: context)
        log(row, on: date(2026, 10, 1), sets: [(60, 8)], in: context)
        log(row, on: date(2026, 10, 8), sets: [(62.5, 8)], in: context)
        try context.save()

        let exercises = [row, squat]
        let details = WorkoutStats.regressionDetails(WorkoutStats.regressingExercises(exercises: exercises)) {
            WorkoutHistory.historyPoints(for: $0)
        }

        XCTAssertEqual(details.map(\.exercise.name), ["Back Squat"], "Row improved, so only Squat regressed")
        let detail = try XCTUnwrap(details.first)
        let epley = { (weight: Double, reps: Double) in weight * (1 + reps / 30) }
        XCTAssertEqual(detail.comparison.change, epley(100, 6) - epley(110, 5), accuracy: 0.0001)
        XCTAssertEqual(detail.comparison.latest.weight, 100)
        XCTAssertEqual(detail.comparison.previous.weight, 110, "Compared on the top set, not the back-off")
        XCTAssertEqual(detail.consecutiveDips, 1)
        XCTAssertEqual(detail.previousDate, date(2026, 10, 8))
        XCTAssertEqual(detail.points.count, 3)
    }

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            WorkoutDay.self, Exercise.self, ExerciseEntry.self, SetEntry.self,
            WorkoutPlan.self, PlanDay.self, PlanExercise.self,
            UserProfile.self, Dashboard.self, DashboardWidget.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        // Keep the container alive for the test: the context only holds it weakly.
        containers.append(container)
        return container.mainContext
    }

    private var containers: [ModelContainer] = []

    private func log(_ exercise: Exercise, on date: Date, sets: [(Double, Int)], in context: ModelContext) {
        let day = WorkoutDay(date: date)
        context.insert(day)
        let entry = ExerciseEntry(exercise: exercise)
        context.insert(entry)
        day.entries.append(entry)
        for (index, set) in sets.enumerated() {
            let model = SetEntry(setNumber: index + 1, weight: set.0, reps: set.1)
            context.insert(model)
            entry.sets.append(model)
        }
    }

    private func sessionRecords(_ context: ModelContext) throws -> [SessionRecord] {
        try context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
            .map { SessionRecord($0) }
    }

    /// Noon local time, so no time zone puts it on another day.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
