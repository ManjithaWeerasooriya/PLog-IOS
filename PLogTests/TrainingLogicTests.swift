//
//  TrainingLogicTests.swift
//  PLogTests
//
//  The session screen's logic: which sets get a trend (an unfilled one doesn't, a bodyweight
//  one is judged on reps), the "beat it with" targets, a first weight carrying down an
//  exercise, personal records, reps in reserve and the rest timer.
//

import XCTest
import SwiftData
@testable import PLog

@MainActor
final class TrainingLogicTests: XCTestCase {
    // MARK: - Trend

    func testWeightedSetsAreComparedOnEstimatedOneRepMax() {
        let previous = SetSnapshot(weight: 60, reps: 8)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 65, reps: 6), previous: previous), .improved)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 60, reps: 8), previous: previous), .matched)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 60, reps: 7), previous: previous), .regressed)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 60, reps: 8), previous: nil), ProgressTrend.none)
    }

    /// A plan day is stamped before it's lifted. Those sets used to show a red arrow.
    func testAnUnfilledSetHasNoTrend() {
        let previous = SetSnapshot(weight: 60, reps: 8)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 0, reps: 8), previous: previous), ProgressTrend.none)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 60, reps: 0), previous: previous), ProgressTrend.none)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 60, reps: 8), previous: .init(weight: 60, reps: 0)), ProgressTrend.none)
    }

    /// Estimated 1RM is 0 at 0 kg, so bodyweight sets never used to show progress.
    func testBodyweightSetsAreComparedOnReps() {
        let previous = SetSnapshot(weight: 0, reps: 10)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 0, reps: 12), previous: previous), .improved)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 0, reps: 10), previous: previous), .matched)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 0, reps: 8), previous: previous), .regressed)
        XCTAssertEqual(ProgressiveOverload.trend(current: .init(weight: 5, reps: 6), previous: previous), .improved, "Added load")
    }

    // MARK: - Targets

    func testTargetsToBeatAreOneMoreRepOrTheNextWeightUp() {
        let targets = ProgressiveOverload.targets(toBeat: SetSnapshot(weight: 60, reps: 8), step: 2.5)
        XCTAssertEqual(targets, [SetSnapshot(weight: 60, reps: 9), SetSnapshot(weight: 62.5, reps: 7)])

        XCTAssertEqual(
            ProgressiveOverload.targets(toBeat: SetSnapshot(weight: 0, reps: 12), step: 2.5),
            [SetSnapshot(weight: 0, reps: 13)],
            "A bodyweight set only has a rep target"
        )
        XCTAssertTrue(ProgressiveOverload.targets(toBeat: SetSnapshot(weight: 60, reps: 0), step: 2.5).isEmpty)
    }

    /// Every target must actually beat the set, and the heavier one must be the fewest reps
    /// that does: one rep fewer has to fall short.
    func testEveryTargetBeatsTheSetAndTheHeavierOneIsMinimal() {
        for step in [2.5, 5.0] {
            for weight in [2.5, 20, 42.5, 100, 135, 300] {
                for reps in 1...25 {
                    let previous = SetSnapshot(weight: weight, reps: reps)
                    let targets = ProgressiveOverload.targets(toBeat: previous, step: step)
                    XCTAssertEqual(targets.count, 2)
                    for target in targets {
                        XCTAssertEqual(
                            ProgressiveOverload.trend(current: target, previous: previous), .improved,
                            "\(target) should beat \(previous)"
                        )
                    }
                    let heavier = targets[1]
                    XCTAssertEqual(heavier.weight, weight + step)
                    if heavier.reps > 1 {
                        let oneFewer = SetSnapshot(weight: heavier.weight, reps: heavier.reps - 1)
                        XCTAssertNotEqual(
                            ProgressiveOverload.trend(current: oneFewer, previous: previous), .improved,
                            "\(oneFewer) shouldn't already beat \(previous)"
                        )
                    }
                }
            }
        }
    }

    func testSetLabels() {
        XCTAssertEqual(ProgressiveOverload.setLabel(.init(weight: 62.5, reps: 8), unit: .kg), "62.5 kg × 8")
        XCTAssertEqual(ProgressiveOverload.setLabel(.init(weight: 135, reps: 5), unit: .lb), "135 lb × 5")
        XCTAssertEqual(ProgressiveOverload.setLabel(.init(weight: 0, reps: 1), unit: .kg), "1 rep")
        XCTAssertEqual(ProgressiveOverload.lastTimeLabel(for: .init(weight: 60, reps: 8), unit: .kg), "Last time: 60 kg × 8")
        XCTAssertNil(ProgressiveOverload.lastTimeLabel(for: nil, unit: .kg))
    }

    // MARK: - A first weight carries down

    func testAFirstWeightFillsTheUntouchedSetsAfterIt() throws {
        let context = try makeContext()
        let entry = try makeEntry(sets: [(0, 8), (0, 8), (40, 8), (0, 8)], in: context)
        let drop = SetEntry(setNumber: 5, weight: 0, reps: 8, isDrop: true)
        context.insert(drop)
        entry.sets.append(drop)
        let model = ExerciseEntryViewModel(entry: entry, context: context)
        let sets = entry.orderedSets
        let start = Date(timeIntervalSinceReferenceDate: 0)

        // Stepping up from zero: 0 → 2.5 → 5, a tick apart.
        step(sets[0], to: 2.5, model: model, at: start)
        step(sets[0], to: 5, model: model, at: start.addingTimeInterval(0.1))

        XCTAssertEqual(sets.map(\.weight), [5, 5, 40, 5, 0], "Zero sets follow; a set with a weight and a drop don't")

        // Coming back to the first set later is a correction to that set alone.
        step(sets[0], to: 7.5, model: model, at: start.addingTimeInterval(60))
        XCTAssertEqual(sets.map(\.weight), [7.5, 5, 40, 5, 0])
    }

    func testATypedWeightFillsDownInOneGo() throws {
        let context = try makeContext()
        let entry = try makeEntry(sets: [(0, 10), (0, 10), (0, 10)], in: context)
        let model = ExerciseEntryViewModel(entry: entry, context: context)
        let sets = entry.orderedSets

        step(sets[1], to: 60, model: model, at: .now)
        XCTAssertEqual(sets.map(\.weight), [0, 60, 60], "Only the sets after the edited one follow")
    }

    func testSetsThatAlreadyHaveAWeightNeverFollow() throws {
        let context = try makeContext()
        let entry = try makeEntry(sets: [(60, 8), (60, 8), (60, 8)], in: context)
        let model = ExerciseEntryViewModel(entry: entry, context: context)
        let sets = entry.orderedSets

        step(sets[0], to: 62.5, model: model, at: .now)
        XCTAssertEqual(sets.map(\.weight), [62.5, 60, 60], "Last session's prefill is left alone")
    }

    func testEditingAnotherSetEndsTheFollow() throws {
        let context = try makeContext()
        let entry = try makeEntry(sets: [(0, 8), (0, 8), (0, 8)], in: context)
        let model = ExerciseEntryViewModel(entry: entry, context: context)
        let sets = entry.orderedSets
        let start = Date(timeIntervalSinceReferenceDate: 0)

        step(sets[0], to: 50, model: model, at: start)
        step(sets[1], to: 47.5, model: model, at: start.addingTimeInterval(0.5))
        step(sets[0], to: 52.5, model: model, at: start.addingTimeInterval(1))
        XCTAssertEqual(sets.map(\.weight), [52.5, 47.5, 50])
    }

    // MARK: - Personal records

    func testOnlyTheBestSetAboveEveryEarlierSessionIsARecord() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", category: .chest)
        context.insert(bench)
        log(bench, daysAgo: 14, sets: [(60, 8), (60, 8)], in: context)
        log(bench, daysAgo: 7, sets: [(62.5, 8), (60, 8)], in: context)
        let entry = log(bench, daysAgo: 0, sets: [(62.5, 8), (60, 8)], in: context)
        let sets = entry.orderedSets

        XCTAssertNil(ExerciseEntryViewModel(entry: entry, context: context).recordSet, "Matching the best isn't a record")

        sets[0].weight = 65
        sets[1].weight = 65
        sets[1].reps = 9
        let model = ExerciseEntryViewModel(entry: entry, context: context)
        XCTAssertTrue(model.recordSet === sets[1], "The better of two record sets carries the mark")
        XCTAssertTrue(model.context(for: sets[1]).isRecord)
        XCTAssertFalse(model.context(for: sets[0]).isRecord)
        XCTAssertEqual(model.context(for: sets[0]).previous, SetSnapshot(weight: 62.5, reps: 8))
    }

    func testTheFirstTimeAnExerciseIsLoggedIsNotARecord() throws {
        let context = try makeContext()
        let squat = Exercise(name: "Back Squat", category: .quads)
        context.insert(squat)
        let entry = log(squat, daysAgo: 0, sets: [(100, 5)], in: context)
        XCTAssertNil(ExerciseEntryViewModel(entry: entry, context: context).recordSet)
    }

    /// Editing an old session compares it with what came before it, not with later ones.
    func testARecordIsJudgedAgainstEarlierSessionsOnly() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", category: .chest)
        context.insert(bench)
        log(bench, daysAgo: 21, sets: [(60, 8)], in: context)
        let middle = log(bench, daysAgo: 14, sets: [(65, 8)], in: context)
        log(bench, daysAgo: 7, sets: [(80, 8)], in: context)

        XCTAssertEqual(WorkoutHistory.bestEstimatedOneRepMax(for: bench, before: middle), SetSnapshot(weight: 60, reps: 8).estimatedOneRepMax)
        XCTAssertNotNil(ExerciseEntryViewModel(entry: middle, context: context).recordSet)
    }

    func testTopSetIsTheHeaviestThenTheMostReps() throws {
        let context = try makeContext()
        let entry = try makeEntry(sets: [(60, 6), (60, 9), (55, 12)], in: context)
        XCTAssertEqual(WorkoutHistory.topSet(of: entry.sets), SetSnapshot(weight: 60, reps: 9))

        let pullUps = try makeEntry(sets: [(0, 8), (0, 11), (0, 9)], in: context)
        XCTAssertEqual(WorkoutHistory.topSet(of: pullUps.sets), SetSnapshot(weight: 0, reps: 11))
        XCTAssertNil(WorkoutHistory.topSet(of: []))
    }

    /// A session stamped from a plan and not yet filled in mustn't turn up under Regressing.
    func testAnUnfilledSessionIsNotARegression() throws {
        let context = try makeContext()
        let bench = Exercise(name: "Bench Press", category: .chest)
        context.insert(bench)
        log(bench, daysAgo: 7, sets: [(60, 8)], in: context)
        log(bench, daysAgo: 0, sets: [(0, 8)], in: context)
        XCTAssertTrue(WorkoutStats.regressingExercises(exercises: [bench]).isEmpty)
    }

    // MARK: - Reps in reserve

    func testRepsInReserveIsStoredAsRPE() {
        let set = SetEntry(setNumber: 1, weight: 60, reps: 8)
        XCTAssertNil(set.repsInReserve)

        set.repsInReserve = 2
        XCTAssertEqual(set.rpe, 8)
        set.repsInReserve = 0
        XCTAssertEqual(set.rpe, 10)
        set.repsInReserve = 9
        XCTAssertEqual(set.repsInReserve, 4, "Four stands for four or more")
        set.repsInReserve = nil
        XCTAssertNil(set.rpe)

        set.rpe = 8.5
        XCTAssertEqual(set.repsInReserve, 2)
        set.rpe = 3
        XCTAssertEqual(set.repsInReserve, 4)
        XCTAssertEqual(EffortTracking.label(4), "4+")
        XCTAssertEqual(EffortTracking.label(1), "1")
    }

    // MARK: - Rest timer

    func testRestTimerCountsDownAgainstItsEndDate() throws {
        let timer = RestTimer(defaults: try scratchDefaults())
        XCTAssertEqual(timer.duration, RestTimer.defaultDuration)
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.remaining(), 0)

        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        timer.duration = 90
        timer.start(now: start)
        XCTAssertTrue(timer.isRunning)
        XCTAssertEqual(timer.remaining(at: start), 90)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(30)), 60)
        XCTAssertEqual(timer.progress(at: start.addingTimeInterval(45)), 0.5, accuracy: 0.001)
        XCTAssertEqual(timer.remaining(at: start.addingTimeInterval(500)), 0, "Never negative")

        timer.add(30, now: start)
        XCTAssertEqual(timer.remaining(at: start), 120)
        XCTAssertEqual(timer.progress(at: start.addingTimeInterval(60)), 0.5, accuracy: 0.001)

        timer.finish()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.finishedCount, 1)
        timer.finish()
        XCTAssertEqual(timer.finishedCount, 1, "Finishing an idle timer does nothing")

        timer.start(now: start)
        timer.stop()
        XCTAssertFalse(timer.isRunning)
        XCTAssertEqual(timer.finishedCount, 1, "Stopping isn't finishing")
    }

    func testRestTimerRemembersItsLength() throws {
        let defaults = try scratchDefaults()
        RestTimer(defaults: defaults).duration = 180
        XCTAssertEqual(RestTimer(defaults: defaults).duration, 180)
    }

    func testRestTimerFormatting() {
        XCTAssertEqual(RestTimer.clock(120), "2:00")
        XCTAssertEqual(RestTimer.clock(59.2), "1:00", "Rounds up, so it never shows 0:00 with time left")
        XCTAssertEqual(RestTimer.clock(5), "0:05")
        XCTAssertEqual(RestTimer.clock(0), "0:00")
        XCTAssertEqual(RestTimer.spoken(90), "1 min 30 sec")
        XCTAssertEqual(RestTimer.spoken(120), "2 min")
        XCTAssertEqual(RestTimer.spoken(45), "45 sec")
    }

    // MARK: - Timing

    /// Opening an exercise asks for its all-time best, which reads every earlier set. With
    /// two years of history that has to stay well inside a frame or two.
    func testRecordLookupTimingWithTwoYearsOfHistory() throws {
        let container = try AppStore.inMemoryContainer()
        containers.append(container)
        let context = container.mainContext
        context.autosaveEnabled = false
        StarterData.seedIfNeeded(in: context)
        let plan = PlanTemplate.pushPullLegs.install(in: context, start: true)
        XCTAssertGreaterThan(DebugHistory.generate(in: context), 400)
        let day = WorkoutLogger.logWorkout(for: try XCTUnwrap(plan.orderedDays.first), in: context)
        let entry = try XCTUnwrap(day.orderedEntries.first)

        // Measured in the simulator: about 50 ms for the very first read, 4 ms after.
        measure {
            let model = ExerciseEntryViewModel(entry: entry, context: context)
            for set in entry.orderedSets {
                _ = model.context(for: set)
            }
        }
    }

    // MARK: - Helpers

    private var containers: [ModelContainer] = []

    private func makeContext() throws -> ModelContext {
        let container = try AppStore.inMemoryContainer()
        // Keep the container alive for the test: the context only holds it weakly.
        containers.append(container)
        return container.mainContext
    }

    private func scratchDefaults() throws -> UserDefaults {
        let name = "PLogTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return defaults
    }

    private func makeEntry(sets: [(Double, Int)], in context: ModelContext) throws -> ExerciseEntry {
        let exercise = Exercise(name: "Exercise \(UUID().uuidString.prefix(4))", category: .chest)
        context.insert(exercise)
        return log(exercise, daysAgo: 0, sets: sets, in: context)
    }

    @discardableResult
    private func log(_ exercise: Exercise, daysAgo: Int, sets: [(Double, Int)], in context: ModelContext) -> ExerciseEntry {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
        let day = WorkoutDay(date: date)
        context.insert(day)
        let entry = ExerciseEntry(exercise: exercise)
        context.insert(entry)
        day.entries.append(entry)
        for (index, values) in sets.enumerated() {
            let set = SetEntry(setNumber: index + 1, weight: values.0, reps: values.1)
            context.insert(set)
            entry.sets.append(set)
        }
        return entry
    }

    /// What `SetRow`'s weight binding does: write the weight, then report the change.
    private func step(_ set: SetEntry, to weight: Double, model: ExerciseEntryViewModel, at date: Date) {
        let old = set.weight
        set.weight = weight
        model.weightChanged(of: set, from: old, to: weight, at: date)
    }
}
