//
//  AppDataTests.swift
//  PLogTests
//
//  Data that has to stay right across installs and backups: the weight unit and converting
//  stored weights, the starter library, the ready-made programs (each must meet the weekly
//  set target it's sold on), the body-weight log, and the backup format's version 8.
//

import XCTest
import SwiftData
@testable import PLog

@MainActor
final class AppDataTests: XCTestCase {
    // MARK: - Weight unit

    func testUnitFollowsTheRegionOnAFreshInstallOnly() throws {
        XCTAssertEqual(WeightUnit.regionDefault(for: Locale(identifier: "en_US")), .lb)
        XCTAssertEqual(WeightUnit.regionDefault(for: Locale(identifier: "en_GB")), .kg)
        XCTAssertEqual(WeightUnit.regionDefault(for: Locale(identifier: "de_DE")), .kg)

        let fresh = try scratchDefaults()
        WeightUnit.chooseDefaultIfUnset(isFreshInstall: true, defaults: fresh, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(fresh.string(forKey: WeightUnit.storageKey), "lb")

        // A store from before the setting existed was logged in kilograms, wherever it is.
        let existing = try scratchDefaults()
        WeightUnit.chooseDefaultIfUnset(isFreshInstall: false, defaults: existing, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(existing.string(forKey: WeightUnit.storageKey), "kg")

        // And a choice already made is never overwritten.
        WeightUnit.chooseDefaultIfUnset(isFreshInstall: true, defaults: existing, locale: Locale(identifier: "en_US"))
        XCTAssertEqual(existing.string(forKey: WeightUnit.storageKey), "kg")
    }

    func testConversionRoundsToOneDecimal() {
        XCTAssertEqual(WeightUnit.kg.convert(100, to: .lb), 220.5)
        XCTAssertEqual(WeightUnit.lb.convert(135, to: .kg), 61.2)
        XCTAssertEqual(WeightUnit.kg.convert(62.5, to: .kg), 62.5)
        XCTAssertEqual(WeightUnit.kg.convert(0, to: .lb), 0)
        XCTAssertEqual(WeightUnit.kg.roundedToStep(48.1), 47.5)
        XCTAssertEqual(WeightUnit.lb.roundedToStep(108), 110)
        XCTAssertEqual(WeightUnit.lb.string(135), "135 lb")
    }

    func testConvertingStoredWeightsCoversSetsProfileAndBodyWeight() throws {
        let context = try makeContext()
        UserProfile.ensureExists(in: context)
        let exercise = Exercise(name: "Bench Press", category: .chest)
        context.insert(exercise)
        let day = WorkoutDay()
        context.insert(day)
        let entry = ExerciseEntry(exercise: exercise)
        context.insert(entry)
        day.entries.append(entry)
        for (index, weight) in [100.0, 60, 0].enumerated() {
            let set = SetEntry(setNumber: index + 1, weight: weight, reps: 8)
            context.insert(set)
            entry.sets.append(set)
        }
        BodyWeightLog.record(80, in: context)

        let changed = try WeightUnit.convertStoredWeights(from: .kg, to: .lb, in: context)

        XCTAssertEqual(changed, 3)
        XCTAssertEqual(entry.orderedSets.map(\.weight), [220.5, 132.3, 0])
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).first?.weightKg, 176.4)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BodyWeightEntry>()).first?.weight, 176.4)
        XCTAssertEqual(try WeightUnit.convertStoredWeights(from: .lb, to: .lb, in: context), 0)
    }

    // MARK: - Starter library

    func testLibraryNamesAreUniqueAndEveryExerciseHasAPrimaryGroup() {
        let names = StarterData.library.map { $0.name.lowercased() }
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertGreaterThanOrEqual(names.count, 50)
        for definition in StarterData.library {
            XCTAssertFalse(definition.primary.isEmpty, definition.name)
            XCTAssertTrue(definition.primary.isDisjoint(with: definition.secondary), definition.name)
        }
    }

    func testSeedingHappensOnceAndReportsAFreshInstall() throws {
        let context = try makeContext()
        XCTAssertTrue(StarterData.seedIfNeeded(in: context))
        XCTAssertFalse(StarterData.seedIfNeeded(in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), StarterData.library.count)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutPlan>()), 0, "Plans come from the welcome sheet now")
    }

    func testAddingMissingExercisesLeavesExistingOnesAlone() throws {
        let context = try makeContext()
        let mine = Exercise(name: "bench press", category: .other, notes: "Pause at the chest")
        context.insert(mine)
        try context.save()

        XCTAssertEqual(StarterData.addMissingExercises(in: context), StarterData.library.count - 1)
        XCTAssertEqual(StarterData.addMissingExercises(in: context), 0)

        let benches = try context.fetch(FetchDescriptor<Exercise>()).filter { $0.name.lowercased() == "bench press" }
        XCTAssertEqual(benches.count, 1, "Matched by name, ignoring case")
        XCTAssertEqual(benches.first?.notes, "Pause at the chest")
        XCTAssertEqual(benches.first?.category, .other)
    }

    // MARK: - Programs

    /// The promise on the program picker: ten or more weekly sets for the main muscle
    /// groups, and nothing above the app's own "high" line.
    func testEveryProgramReachesTheWeeklyTargetForTheMainMuscleGroups() throws {
        let main: [MuscleGroup] = [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes]
        for template in PlanTemplate.all {
            let context = try makeContext()
            StarterData.seedIfNeeded(in: context)
            let plan = template.install(in: context, start: false)
            let summary = PlanVolume.summary(for: plan)

            XCTAssertEqual(plan.daysPerWeek, template.daysPerWeek, template.name)
            for group in main {
                let sets = summary.groups.first { $0.group == group }?.weeklySets ?? 0
                XCTAssertGreaterThanOrEqual(sets, HypertrophyTarget.minimumWeeklySets, "\(template.name): \(group.displayName)")
            }
            XCTAssertEqual(summary.highCount, 0, "\(template.name) has a group above the high line")
            XCTAssertNil(summary.groups.first { $0.group == .other }, "\(template.name) uses an exercise the library doesn't know")
            XCTAssertEqual(
                try context.fetchCount(FetchDescriptor<Exercise>()), StarterData.library.count,
                "\(template.name) created an exercise instead of using the library's"
            )
        }
    }

    func testProgramDaysPerWeek() {
        XCTAssertEqual(PlanTemplate.fullBody.daysPerWeek, 3)
        XCTAssertEqual(PlanTemplate.upperLower.daysPerWeek, 4)
        XCTAssertEqual(PlanTemplate.pushPullLegs.daysPerWeek, 6)
        XCTAssertEqual(PlanTemplate.pushPullLegs.frequencyLabel, "6 days a week")
        XCTAssertEqual(Set(PlanTemplate.all.map(\.id)).count, PlanTemplate.all.count)
    }

    func testInstallingAProgramStartsItAndEndsTheActivePlan() throws {
        let context = try makeContext()
        // No library at all: the program brings its own exercises.
        let first = PlanTemplate.fullBody.install(in: context, start: true)
        XCTAssertTrue(first.isActive)
        XCTAssertEqual(first.orderedDays.map(\.name), ["Full Body A", "Full Body B", "Full Body C"])
        XCTAssertEqual(first.orderedDays.first?.orderedExercises.first?.exercise?.name, "Back Squat")
        XCTAssertEqual(first.orderedDays.first?.orderedExercises.first?.exercise?.category, .quads)

        let second = PlanTemplate.pushPullLegs.install(in: context, start: true)
        XCTAssertTrue(second.isActive)
        XCTAssertFalse(first.isActive, "Only one plan is ever active")
        XCTAssertEqual(second.orderedDays.map(\.timesPerWeek), [2, 2, 2])

        let again = PlanTemplate.fullBody.install(in: context, start: false)
        XCTAssertEqual(again.name, "Full Body (1)", "A second copy is told apart by name")
        XCTAssertFalse(again.isActive)
        XCTAssertTrue(second.isActive, "Adding without starting leaves the active plan alone")

        // Shared exercises are reused, not duplicated.
        let squats = try context.fetch(FetchDescriptor<Exercise>()).filter { $0.name == "Back Squat" }
        XCTAssertEqual(squats.count, 1)
    }

    // MARK: - Body weight

    func testOneReadingADayAndTheProfileFollowsTheLatest() throws {
        let context = try makeContext()
        UserProfile.ensureExists(in: context)
        let calendar = Calendar.current
        let today = Date.now
        let lastWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: -7, to: today))

        BodyWeightLog.record(80, on: lastWeek, in: context)
        BodyWeightLog.record(79.5, on: today, in: context)
        BodyWeightLog.record(79, on: today, in: context)

        var entries = try context.fetch(FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date)]))
        XCTAssertEqual(entries.map(\.weight), [80, 79], "Logging twice in a day replaces the reading")
        let profile = try XCTUnwrap(context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(profile.weightKg, 79)

        // A back-dated reading doesn't become the current weight.
        BodyWeightLog.record(81, on: try XCTUnwrap(calendar.date(byAdding: .day, value: -30, to: today)), in: context)
        XCTAssertEqual(profile.weightKg, 79)

        // Removing today's reading falls back to the one before it.
        entries = try context.fetch(FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date)]))
        BodyWeightLog.delete(try XCTUnwrap(entries.last), in: context)
        XCTAssertEqual(profile.weightKg, 80)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyWeightEntry>()), 2)
    }

    func testBodyWeightChangeIsMeasuredFromAboutAMonthBack() throws {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        func reading(_ daysAgo: Int, _ weight: Double) throws -> BodyWeightLog.Reading {
            .init(date: try XCTUnwrap(calendar.date(byAdding: .day, value: -daysAgo, to: today)), weight: weight)
        }

        XCTAssertNil(BodyWeightLog.change(in: [try reading(0, 80)]), "One reading has nothing to compare with")

        let long = [try reading(90, 84), try reading(35, 82), try reading(10, 81), try reading(0, 80.4)]
        let change = try XCTUnwrap(BodyWeightLog.change(in: long))
        XCTAssertEqual(change.amount, -1.6, "Against the reading at or before 30 days ago")
        XCTAssertEqual(change.since, long[1].date)

        // Less than a month of readings: from the first one.
        let short = [try reading(6, 80), try reading(0, 80.7)]
        XCTAssertEqual(try XCTUnwrap(BodyWeightLog.change(in: short)).amount, 0.7)
    }

    // MARK: - Backup

    func testBackupRoundTripKeepsBodyWeightUnitAndEffort() throws {
        let source = try makeContext()
        UserProfile.ensureExists(in: source)
        Dashboard.ensureExists(in: source)
        StarterData.seedIfNeeded(in: source)
        let plan = PlanTemplate.upperLower.install(in: source, start: true)
        let day = WorkoutLogger.logWorkout(for: try XCTUnwrap(plan.orderedDays.first), in: source)
        let set = try XCTUnwrap(day.orderedEntries.first?.orderedSets.first)
        set.weight = 135
        set.repsInReserve = 1
        BodyWeightLog.record(180, in: source)

        let data = try DataBackup.export(from: source)
        var backup = try DataBackup.decode(data)
        XCTAssertEqual(backup.version, 8)
        XCTAssertEqual(backup.bodyWeights?.count, 1)
        backup.weightUnit = "lb"

        let target = try makeContext()
        UserProfile.ensureExists(in: target)
        let defaults = try scratchDefaults()
        try DataBackup.restore(backup, into: target, defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: WeightUnit.storageKey), "lb", "The numbers arrive with their unit")
        XCTAssertEqual(try target.fetch(FetchDescriptor<BodyWeightEntry>()).map(\.weight), [180])
        XCTAssertEqual(try target.fetch(FetchDescriptor<UserProfile>()).first?.weightKg, 180)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Exercise>()), StarterData.library.count)
        let restored = try XCTUnwrap(target.fetch(FetchDescriptor<WorkoutDay>()).first?.orderedEntries.first?.orderedSets.first)
        XCTAssertEqual(restored.weight, 135)
        XCTAssertEqual(restored.repsInReserve, 1)
        XCTAssertEqual(try target.fetch(FetchDescriptor<WorkoutPlan>()).first?.isActive, true)
    }

    /// A version 7 file has neither key; it must still import, and leave the unit alone.
    func testAnOlderBackupImportsWithoutBodyWeightOrUnit() throws {
        let source = try makeContext()
        UserProfile.ensureExists(in: source)
        StarterData.seedIfNeeded(in: source)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: DataBackup.export(from: source)) as? [String: Any])
        json["version"] = 7
        json["weightUnit"] = nil
        json["bodyWeights"] = nil
        let backup = try DataBackup.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(backup.weightUnit)

        let target = try makeContext()
        let defaults = try scratchDefaults()
        try DataBackup.restore(backup, into: target, defaults: defaults)
        XCTAssertNil(defaults.string(forKey: WeightUnit.storageKey))
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<BodyWeightEntry>()), 0)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<Exercise>()), StarterData.library.count)
    }

    func testANewerBackupIsRefused() throws {
        let source = try makeContext()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: DataBackup.export(from: source)) as? [String: Any])
        json["version"] = PLogBackup.currentVersion + 1
        XCTAssertThrowsError(try DataBackup.decode(JSONSerialization.data(withJSONObject: json)))
        XCTAssertThrowsError(try DataBackup.decode(Data("not json".utf8)))
    }

    func testImportClampsImpossibleNumbers() throws {
        let source = try makeContext()
        UserProfile.ensureExists(in: source)
        let exercise = Exercise(name: "Bench Press", category: .chest)
        source.insert(exercise)
        let day = WorkoutDay()
        source.insert(day)
        let entry = ExerciseEntry(exercise: exercise)
        source.insert(entry)
        day.entries.append(entry)
        let set = SetEntry(setNumber: 1, weight: -40, reps: -3, rpe: 14)
        source.insert(set)
        entry.sets.append(set)
        source.insert(BodyWeightEntry(weight: -5))
        try source.save()

        let target = try makeContext()
        try DataBackup.restore(DataBackup.decode(DataBackup.export(from: source)), into: target, defaults: try scratchDefaults())

        let restored = try XCTUnwrap(target.fetch(FetchDescriptor<SetEntry>()).first)
        XCTAssertEqual(restored.weight, 0)
        XCTAssertEqual(restored.reps, 0)
        XCTAssertEqual(restored.rpe, 10)
        XCTAssertEqual(try target.fetchCount(FetchDescriptor<BodyWeightEntry>()), 0, "A reading of nothing is dropped")
    }

    /// "Replace All Data" must never leave half an import behind. Everything that can fail
    /// is read before the first change, so the replace is one step that can't throw: after
    /// it the context holds the whole backup and none of what was there before.
    func testReplacingContentsIsCompleteInOneStep() throws {
        let source = try makeContext()
        UserProfile.ensureExists(in: source)
        StarterData.seedIfNeeded(in: source)
        let sourcePlan = PlanTemplate.upperLower.install(in: source, start: true)
        WorkoutLogger.logWorkout(for: try XCTUnwrap(sourcePlan.orderedDays.first), in: source)
        let backup = try DataBackup.decode(DataBackup.export(from: source))

        let context = try makeContext()
        UserProfile.ensureExists(in: context)
        Dashboard.ensureExists(in: context)
        let mine = Exercise(name: "My Own Lift", category: .other)
        context.insert(mine)
        let oldPlan = PlanTemplate.fullBody.install(in: context, start: true)
        WorkoutLogger.logWorkout(for: try XCTUnwrap(oldPlan.orderedDays.first), in: context)
        BodyWeightLog.record(80, in: context)
        try context.save()

        let current = try DataBackup.CurrentContents(in: context)
        DataBackup.replaceContents(current, with: backup, in: context)
        try context.save()

        XCTAssertEqual(try counts(in: context), try counts(in: source))
        XCTAssertEqual(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name), ["Upper / Lower"])
        XCTAssertFalse(try context.fetch(FetchDescriptor<Exercise>()).contains { $0.name == "My Own Lift" })
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1, "The profile is updated in place")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Dashboard>()), 1)
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

    private func counts(in context: ModelContext) throws -> [Int] {
        [
            try context.fetchCount(FetchDescriptor<WorkoutDay>()),
            try context.fetchCount(FetchDescriptor<ExerciseEntry>()),
            try context.fetchCount(FetchDescriptor<SetEntry>()),
            try context.fetchCount(FetchDescriptor<WorkoutPlan>()),
            try context.fetchCount(FetchDescriptor<PlanDay>()),
            try context.fetchCount(FetchDescriptor<PlanExercise>()),
            try context.fetchCount(FetchDescriptor<Exercise>()),
            try context.fetchCount(FetchDescriptor<BodyWeightEntry>()),
        ]
    }
}
