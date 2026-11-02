//
//  StarterData.swift
//  PLog
//
//  Seeds a starter exercise library and two sample plans the first time the app runs with an
//  empty store, so there's something to log against straight away. Separate from
//  `SampleData`, which is the in-memory preview fixture (and also seeds workout history).
//

import Foundation
import SwiftData

@MainActor
enum StarterData {
    /// Seeds only when the store has no exercises at all, so it never touches real data.
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existing == 0 else { return }
        seed(into: context)
    }

    private static func seed(into context: ModelContext) {
        // Master exercise library: name, primary groups, secondary groups.
        let library: [(String, Set<MuscleGroup>, Set<MuscleGroup>)] = [
            ("Bench Press", [.chest], [.triceps, .shoulders]),
            ("Incline Dumbbell Press", [.chest], [.shoulders, .triceps]),
            ("Cable Fly", [.chest], []),
            ("Deadlift", [.back, .hamstrings], [.glutes, .traps, .forearms]),
            ("Barbell Row", [.back], [.biceps, .rearDelts]),
            ("Lat Pulldown", [.back], [.biceps]),
            ("Seated Cable Row", [.back], [.biceps, .rearDelts]),
            ("Back Squat", [.quads, .glutes], [.hamstrings, .core]),
            ("Romanian Deadlift", [.hamstrings], [.glutes, .back]),
            ("Leg Press", [.quads], [.glutes]),
            ("Leg Curl", [.hamstrings], []),
            ("Calf Raise", [.calves], []),
            ("Overhead Press", [.shoulders], [.triceps]),
            ("Lateral Raise", [.shoulders], []),
            ("Face Pull", [.rearDelts], [.traps]),
            ("Bicep Curl", [.biceps], [.forearms]),
            ("Hammer Curl", [.biceps], [.forearms]),
            ("Tricep Pushdown", [.triceps], []),
            ("Plank", [.core], []),
            ("Hanging Leg Raise", [.core], []),
        ]
        var exercises: [String: Exercise] = [:]
        for (name, primary, secondary) in library {
            let exercise = Exercise(name: name)
            exercise.setMuscles(primary: primary, secondary: secondary)
            context.insert(exercise)
            exercises[name] = exercise
        }

        // An active Push / Pull / Legs plan — the one the Logs tab will offer right away.
        let ppl = makePlan(
            named: "Push / Pull / Legs",
            days: [
                ("Push Day", [("Bench Press", 4, 8), ("Incline Dumbbell Press", 3, 10),
                              ("Overhead Press", 3, 8), ("Lateral Raise", 3, 15), ("Tricep Pushdown", 3, 12)]),
                ("Pull Day", [("Deadlift", 3, 5), ("Lat Pulldown", 3, 10), ("Barbell Row", 3, 8),
                              ("Face Pull", 3, 15), ("Bicep Curl", 3, 12)]),
                ("Leg Day", [("Back Squat", 4, 6), ("Romanian Deadlift", 3, 8), ("Leg Press", 3, 12),
                             ("Leg Curl", 3, 12), ("Calf Raise", 4, 15)]),
            ],
            exercises: exercises,
            in: context
        )
        ppl.startedAt = .now

        // A second, not-started plan so the "only one active plan" rule can be exercised.
        makePlan(
            named: "Upper / Lower",
            days: [
                ("Upper Day", [("Bench Press", 3, 8), ("Barbell Row", 3, 8),
                               ("Overhead Press", 3, 10), ("Lat Pulldown", 3, 10), ("Hammer Curl", 3, 12)]),
                ("Lower Day", [("Back Squat", 3, 6), ("Romanian Deadlift", 3, 10),
                               ("Leg Press", 3, 12), ("Calf Raise", 3, 15), ("Plank", 3, 1)]),
            ],
            exercises: exercises,
            in: context
        )

        try? context.save()
    }

    /// Builds a plan with its day templates and slots, appending through the to-many side
    /// so Observation fires on the parents.
    @discardableResult
    private static func makePlan(
        named name: String,
        days: [(name: String, slots: [(exercise: String, sets: Int, reps: Int)])],
        exercises: [String: Exercise],
        in context: ModelContext
    ) -> WorkoutPlan {
        let plan = WorkoutPlan(name: name)
        context.insert(plan)

        for (dayOrder, dayTemplate) in days.enumerated() {
            let day = PlanDay(name: dayTemplate.name, order: dayOrder)
            context.insert(day)
            plan.days.append(day)

            for (slotOrder, slot) in dayTemplate.slots.enumerated() {
                guard let exercise = exercises[slot.exercise] else { continue }
                let planExercise = PlanExercise(
                    exercise: exercise,
                    order: slotOrder,
                    targetSets: slot.sets,
                    targetReps: slot.reps
                )
                context.insert(planExercise)
                day.exercises.append(planExercise)
            }
        }
        return plan
    }
}
