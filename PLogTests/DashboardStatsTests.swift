//
//  DashboardStatsTests.swift
//  PLogTests
//
//  Guards the Progress dashboard's speed and its incremental cache. With two years of
//  generated history (the same generator as Settings ▸ Debug): figures rebuilt from the
//  `SessionRecordCache` after edits must match a full rebuild exactly, and the timing tests
//  report how long a full build and a cached rebuild take, so a slow path coming back shows
//  up here first. See AGENT.md ("Widgets never read workouts or sets in `body`").
//

import XCTest
import SwiftData
@testable import PLog

final class DashboardStatsTests: XCTestCase {
    // MARK: - Correctness

    /// An edit, an added set, a deleted set, a deleted session and a changed exercise all
    /// reach the cache through saves; its figures must equal ones built from scratch.
    func testCachedRebuildMatchesFullRebuildAfterEdits() throws {
        let container = try makeHistory()
        let context = container.mainContext
        let today = Date.now
        let cache = SessionRecordCache()
        let before = try dashboardData(context)
        let beforeStats = DashboardStats(data: before, records: cache.records(for: before.workouts), today: today)

        let observer = observeSaves(into: cache, context: context)
        defer { NotificationCenter.default.removeObserver(observer) }

        let sessions = before.workouts
        // Edit a set in the latest session.
        let latestSet = try XCTUnwrap(sessions[0].orderedEntries.first?.orderedSets.first)
        latestSet.weight += 2.5
        try context.save()
        // Add a set to an entry a few sessions back.
        let entry = try XCTUnwrap(sessions[3].orderedEntries.last)
        let added = SetEntry(setNumber: entry.sets.count + 1, weight: 40, reps: 10)
        context.insert(added)
        entry.sets.append(added)
        try context.save()
        // Delete a set from an old session, and a whole session.
        let oldEntry = try XCTUnwrap(sessions[200].orderedEntries.first)
        let doomed = try XCTUnwrap(oldEntry.orderedSets.last)
        oldEntry.sets.removeAll { $0 === doomed }
        context.delete(doomed)
        context.delete(sessions[10])
        try context.save()
        // Change an exercise's muscle groups.
        let bench = try XCTUnwrap(before.exercises.first { $0.name == "Bench Press" })
        bench.setMuscles(primary: [.chest, .shoulders], secondary: [])
        try context.save()

        let after = try dashboardData(context)
        let cached = DashboardStats(data: after, records: cache.records(for: after.workouts), today: today)
        let fresh = DashboardStats(data: after, today: today)
        XCTAssertEqual(fingerprint(cached), fingerprint(fresh))
        XCTAssertNotEqual(fingerprint(cached), fingerprint(beforeStats), "The edits should have changed the figures")
    }

    // MARK: - Timing

    /// A full build, reading every session through SwiftData: what the first Progress open
    /// after launch costs.
    func testFullBuildPerformance() throws {
        let container = try makeHistory()
        let data = try dashboardData(container.mainContext)
        measure {
            _ = DashboardStats(data: data)
        }
    }

    /// A rebuild after one stepper edit: what opening Progress after changing a set costs.
    /// Should stay a small fraction of the full build.
    func testCachedRebuildAfterEditPerformance() throws {
        let container = try makeHistory()
        let context = container.mainContext
        let cache = SessionRecordCache()
        let data = try dashboardData(context)
        _ = cache.records(for: data.workouts)
        let observer = observeSaves(into: cache, context: context)
        defer { NotificationCenter.default.removeObserver(observer) }
        let set = try XCTUnwrap(data.workouts[0].orderedEntries.first?.orderedSets.first)

        measure {
            set.weight += 2.5
            try? context.save()
            _ = DashboardStats(data: data, records: cache.records(for: data.workouts))
        }
    }

    // MARK: - Helpers

    /// The starter library and plans, logged four days a week for two years in memory.
    private func makeHistory() throws -> ModelContainer {
        let schema = Schema([
            WorkoutDay.self, Exercise.self, ExerciseEntry.self, SetEntry.self,
            WorkoutPlan.self, PlanDay.self, PlanExercise.self,
            UserProfile.self, Dashboard.self, DashboardWidget.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        container.mainContext.autosaveEnabled = false
        StarterData.seedIfNeeded(in: container.mainContext)
        XCTAssertGreaterThan(DebugHistory.generate(in: container.mainContext), 400)
        return container
    }

    /// What `AnalyticsView` queries, the same way.
    private func dashboardData(_ context: ModelContext) throws -> DashboardData {
        DashboardData(
            workouts: try context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date, order: .reverse)])),
            plans: try context.fetch(FetchDescriptor<WorkoutPlan>()),
            bodyWeightKg: nil,
            exercises: try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.name)]))
        )
    }

    /// Feeds saves to the cache as `AnalyticsView` does.
    private func observeSaves(into cache: SessionRecordCache, context: ModelContext) -> NSObjectProtocol {
        NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { note in
            MainActor.assumeIsolated { _ = cache.noteSave(note, in: context) }
        }
    }

    /// Every figure as text, with ties put in a fixed order, so two builds compare exactly.
    private func fingerprint(_ stats: DashboardStats) -> String {
        var parts = [
            "workouts \(stats.workoutCount)", "sets \(stats.totalSets)", "streak \(stats.streak)",
            "this week \(stats.thisWeekSessions)", "prev7 \(stats.previous7Volume)",
        ]
        parts += stats.last7Days.map { "day \($0.volume)" }
        for range in AnalyticsRange.allCases {
            parts += (stats.weekly[range] ?? []).map { "week \($0.sessions)/\($0.sets)/\($0.volume)" }
            parts += (stats.muscleSplit[range] ?? []).map { "\($0.group.rawValue) \($0.sets)" }.sorted()
            parts.append("done \(stats.setsDone[range] ?? 0)")
        }
        parts += stats.bestLifts.map { "\($0.exercise.name) \($0.estimatedOneRepMax) \($0.trend)" }.sorted()
        parts += stats.regressions.map { "\($0.exercise.name) \($0.change)" }.sorted()
        for lift in stats.bestLifts {
            parts += stats.points(for: lift.exercise).map { "\($0.date) \($0.topWeight)x\($0.topSetReps) \($0.totalVolume)" }
        }
        return parts.joined(separator: "\n")
    }
}
