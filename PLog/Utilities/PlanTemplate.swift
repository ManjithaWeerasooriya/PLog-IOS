//
//  PlanTemplate.swift
//  PLog
//
//  Ready-made programs a user can start from instead of building a plan slot by slot.
//  Each one is written so the main muscle groups land on the app's own weekly target
//  (`HypertrophyTarget`: 10–30 sets, secondary muscles counting half) — `PlanTemplateTests`
//  holds them to that, so a template can't quietly drift below it. Installing one makes an
//  ordinary `WorkoutPlan` the user can edit like any other.
//

import Foundation
import SwiftData

struct PlanTemplate: Identifiable {
    struct Slot {
        let exercise: String
        let sets: Int
        let reps: Int

        init(_ exercise: String, _ sets: Int, _ reps: Int) {
            self.exercise = exercise
            self.sets = sets
            self.reps = reps
        }
    }

    struct Day {
        let name: String
        /// How many times a week the day runs (`PlanDay.timesPerWeek`).
        var timesPerWeek = 1
        let slots: [Slot]
    }

    let id: String
    let name: String
    /// Who it suits, in a few words.
    let summary: String
    let days: [Day]

    var daysPerWeek: Int {
        days.reduce(0) { $0 + $1.timesPerWeek }
    }

    /// "3 days a week".
    var frequencyLabel: String {
        "\(daysPerWeek) days a week"
    }

    /// "Push Day · Pull Day · Leg Day".
    var dayNames: String {
        days.map(\.name).joined(separator: " · ")
    }

    /// Creates the plan in the store, using the library's exercises (creating any the store
    /// is missing). With `start`, it becomes the active plan and any other active plan ends,
    /// through `WorkoutPlanViewModel.start()` like every other start.
    @MainActor
    @discardableResult
    func install(in context: ModelContext, start: Bool) -> WorkoutPlan {
        let existingNames = ((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []).map(\.name)
        let plan = WorkoutPlan(name: WorkoutPlanViewModel.uniqueName(for: name, existing: existingNames))
        context.insert(plan)

        var exercises: [String: Exercise] = [:]
        for (dayOrder, template) in days.enumerated() {
            let day = PlanDay(name: template.name, order: dayOrder)
            if template.timesPerWeek > 1 { day.timesPerWeek = template.timesPerWeek }
            context.insert(day)
            plan.days.append(day)

            for (slotOrder, slot) in template.slots.enumerated() {
                let planExercise = PlanExercise(
                    exercise: StarterData.exercise(named: slot.exercise, in: context, cache: &exercises),
                    order: slotOrder,
                    targetSets: slot.sets,
                    targetReps: slot.reps
                )
                context.insert(planExercise)
                day.exercises.append(planExercise)
            }
        }

        if start {
            WorkoutPlanViewModel(plan: plan, context: context).start()
        } else {
            context.saveLogged()
        }
        return plan
    }
}

// MARK: - The programs

extension PlanTemplate {
    static let all: [PlanTemplate] = [fullBody, upperLower, pushPullLegs]

    /// Three sessions, each training everything. The fewest gym days that still reach ten
    /// weekly sets for the big muscle groups.
    static let fullBody = PlanTemplate(
        id: "full-body",
        name: "Full Body",
        summary: "Every muscle, every session. A good first program.",
        days: [
            Day(name: "Full Body A", slots: [
                Slot("Back Squat", 4, 8), Slot("Bench Press", 4, 8), Slot("Barbell Row", 3, 10),
                Slot("Lateral Raise", 3, 15), Slot("Leg Curl", 4, 12), Slot("Tricep Pushdown", 3, 12),
                Slot("Bicep Curl", 3, 12),
            ]),
            Day(name: "Full Body B", slots: [
                Slot("Romanian Deadlift", 3, 8), Slot("Incline Dumbbell Press", 3, 10), Slot("Lat Pulldown", 3, 10),
                Slot("Leg Press", 3, 12), Slot("Dumbbell Shoulder Press", 3, 10), Slot("Hammer Curl", 3, 12),
                Slot("Calf Raise", 3, 15),
            ]),
            Day(name: "Full Body C", slots: [
                Slot("Hack Squat", 3, 10), Slot("Machine Chest Press", 3, 10), Slot("Seated Cable Row", 3, 10),
                Slot("Hip Thrust", 3, 10), Slot("Lateral Raise", 3, 15), Slot("Overhead Tricep Extension", 3, 12),
                Slot("Face Pull", 3, 15),
            ]),
        ]
    )

    /// Four sessions: two upper, two lower, so each muscle is trained twice a week.
    static let upperLower = PlanTemplate(
        id: "upper-lower",
        name: "Upper / Lower",
        summary: "Each muscle twice a week, with room for more work per session.",
        days: [
            Day(name: "Upper A", slots: [
                Slot("Bench Press", 4, 8), Slot("Barbell Row", 4, 8), Slot("Overhead Press", 3, 10),
                Slot("Lat Pulldown", 3, 10), Slot("Lateral Raise", 3, 15), Slot("Tricep Pushdown", 3, 12),
                Slot("Bicep Curl", 3, 12),
            ]),
            Day(name: "Lower A", slots: [
                Slot("Back Squat", 4, 6), Slot("Romanian Deadlift", 3, 8), Slot("Leg Press", 3, 12),
                Slot("Leg Curl", 3, 12), Slot("Calf Raise", 4, 12), Slot("Hanging Leg Raise", 3, 12),
            ]),
            Day(name: "Upper B", slots: [
                Slot("Incline Dumbbell Press", 4, 10), Slot("Seated Cable Row", 4, 10), Slot("Cable Fly", 3, 12),
                Slot("Pull-Up", 3, 8), Slot("Face Pull", 3, 15), Slot("Overhead Tricep Extension", 3, 12),
                Slot("Hammer Curl", 3, 12),
            ]),
            Day(name: "Lower B", slots: [
                Slot("Hack Squat", 4, 10), Slot("Hip Thrust", 4, 10), Slot("Leg Extension", 3, 15),
                Slot("Seated Leg Curl", 3, 12), Slot("Seated Calf Raise", 4, 15), Slot("Cable Crunch", 3, 15),
            ]),
        ]
    )

    /// Six sessions: push, pull and legs, each run twice a week.
    static let pushPullLegs = PlanTemplate(
        id: "push-pull-legs",
        name: "Push / Pull / Legs",
        summary: "The classic bodybuilding split, each day run twice a week.",
        days: [
            Day(name: "Push Day", timesPerWeek: 2, slots: [
                Slot("Bench Press", 4, 8), Slot("Incline Dumbbell Press", 3, 10), Slot("Overhead Press", 3, 8),
                Slot("Lateral Raise", 3, 15), Slot("Tricep Pushdown", 3, 12),
            ]),
            Day(name: "Pull Day", timesPerWeek: 2, slots: [
                Slot("Lat Pulldown", 4, 10), Slot("Barbell Row", 3, 8), Slot("Seated Cable Row", 3, 10),
                Slot("Face Pull", 3, 15), Slot("Bicep Curl", 3, 12), Slot("Hammer Curl", 2, 12),
            ]),
            Day(name: "Leg Day", timesPerWeek: 2, slots: [
                Slot("Back Squat", 4, 6), Slot("Romanian Deadlift", 3, 8), Slot("Leg Press", 3, 12),
                Slot("Leg Curl", 3, 12), Slot("Calf Raise", 5, 12), Slot("Hanging Leg Raise", 3, 12),
            ]),
        ]
    )
}
