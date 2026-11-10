//
//  PlanVolumeTests.swift
//  PLogTests
//
//  The plan's weekly sets per muscle group: primary sets count fully, secondary ones half,
//  each day counts its own `timesPerWeek`, and the "reach 10" suggestion picks the biggest
//  primary slot and divides by how often its day runs. Also times a large plan, since the Weekly Sets screen recomputes
//  the summary on every stepper tick.
//

import XCTest
import SwiftData
@testable import PLog

final class PlanVolumeTests: XCTestCase {
    func testWeeklySetsCountPrimaryFullSecondaryHalfAndEachDaysTimesPerWeek() throws {
        let context = try makeContext()
        let bench = exercise("Bench Press", primary: [.chest], secondary: [.triceps], in: context)
        let row = exercise("Barbell Row", primary: [.back], secondary: [.rearDelts], in: context)
        let plan = makePlan([[(bench, 4)], [(row, 3)]], in: context)

        // Default: every day once a week.
        var summary = PlanVolume.summary(for: plan)
        XCTAssertEqual(plan.daysPerWeek, 2)
        XCTAssertEqual(summary.weeklySets, 7)
        XCTAssertEqual(sets(.chest, summary), 4)
        XCTAssertEqual(sets(.triceps, summary), 2)
        XCTAssertEqual(sets(.back, summary), 3)
        XCTAssertEqual(sets(.rearDelts, summary), 1.5)
        XCTAssertEqual(sets(.quads, summary), 0, "Untrained target groups are listed at 0")
        XCTAssertNil(summary.groups.first { $0.group == .cardio }, "Cardio only appears when trained")

        // Only the bench day repeats: three training days a week.
        let benchDay = try XCTUnwrap(plan.orderedDays.first)
        benchDay.timesPerWeek = 2
        summary = PlanVolume.summary(for: plan)
        XCTAssertEqual(plan.daysPerWeek, 3)
        XCTAssertEqual(summary.weeklySets, 11)
        XCTAssertEqual(sets(.chest, summary), 8)
        XCTAssertEqual(sets(.triceps, summary), 4)
        XCTAssertEqual(sets(.back, summary), 3, "The row day still runs once")
        XCTAssertEqual(sets(.rearDelts, summary), 1.5)
        XCTAssertEqual(summary.groups.first?.group, .chest, "Largest first")
    }

    func testSuggestionUsesPrimarySlotAndRoundsUp() throws {
        let context = try makeContext()
        let facePull = exercise("Face Pull", primary: [.rearDelts], secondary: [], in: context)
        let bench = exercise("Bench Press", primary: [.chest], secondary: [.triceps], in: context)
        let plan = makePlan([[(facePull, 3), (bench, 3)]], in: context)
        plan.orderedDays[0].timesPerWeek = 2 // the one day runs twice: 6 rear-delt sets a week

        let summary = PlanVolume.summary(for: plan)
        let rearDelts = try XCTUnwrap(summary.groups.first { $0.group == .rearDelts })
        let suggestion = try XCTUnwrap(PlanVolume.suggestion(for: rearDelts))
        XCTAssertEqual(suggestion.slot.exercise?.name, "Face Pull")
        XCTAssertEqual(suggestion.extraSets, 2, "4 short at 2× a week → 2 more sets per session")

        // Triceps only gets half-sets from Bench: no slot to suggest.
        let triceps = try XCTUnwrap(summary.groups.first { $0.group == .triceps })
        XCTAssertNil(PlanVolume.suggestion(for: triceps))
    }

    func testSetStringDropsZeroDecimal() {
        XCTAssertEqual(PlanVolume.setString(14), "14")
        XCTAssertEqual(PlanVolume.setString(9.5), "9.5")
    }

    /// A 7-day plan with 10 slots a day — far bigger than a real one.
    func testSummaryTiming() throws {
        let context = try makeContext()
        let library = (0..<20).map { index in
            exercise("Exercise \(index)", primary: [MuscleGroup.allCases[index % 13]], secondary: [MuscleGroup.allCases[(index + 3) % 13]], in: context)
        }
        let days = (0..<7).map { day in (0..<10).map { (library[(day * 10 + $0) % 20], 3) } }
        let plan = makePlan(days, in: context)
        try context.save()
        measure {
            _ = PlanVolume.summary(for: plan)
        }
    }

    // MARK: - Helpers

    private func sets(_ group: MuscleGroup, _ summary: PlanVolume.Summary) -> Double? {
        summary.groups.first { $0.group == group }?.weeklySets
    }

    private func exercise(_ name: String, primary: Set<MuscleGroup>, secondary: Set<MuscleGroup>, in context: ModelContext) -> Exercise {
        let exercise = Exercise(name: name)
        exercise.setMuscles(primary: primary, secondary: secondary)
        context.insert(exercise)
        return exercise
    }

    private func makePlan(_ days: [[(Exercise, Int)]], in context: ModelContext) -> WorkoutPlan {
        let plan = WorkoutPlan(name: "Test")
        context.insert(plan)
        for (dayIndex, slots) in days.enumerated() {
            let day = PlanDay(name: "Day \(dayIndex + 1)", order: dayIndex)
            context.insert(day)
            plan.days.append(day)
            for (slotIndex, (exercise, sets)) in slots.enumerated() {
                let slot = PlanExercise(exercise: exercise, order: slotIndex, targetSets: sets)
                context.insert(slot)
                day.exercises.append(slot)
            }
        }
        return plan
    }

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
        containers.append(container)
        return container.mainContext
    }

    private var containers: [ModelContainer] = []
}
