//
//  PlanDay.swift
//  PLog
//
//  One named day template inside a `WorkoutPlan` (e.g. "Push Day") listing the exercises
//  and target sets/reps to pre-populate when that day is logged.
//

import Foundation
import SwiftData

@Model
final class PlanDay {
    /// e.g. "Push Day", "Leg Day".
    var name: String

    /// Position within the plan's rotation.
    var order: Int

    /// The owning plan. Inverse of `WorkoutPlan.days`.
    var plan: WorkoutPlan?

    /// How many times a week this day is trained, for the plan's weekly sets. `nil` (every
    /// day saved before this existed, and a new day) means once — read it through `timesPerWeek`.
    var weeklyFrequency: Int?

    /// The exercise templates for this day.
    ///
    /// Cascade delete: removing the day removes its templates. Inverse on `PlanExercise.planDay`.
    @Relationship(deleteRule: .cascade, inverse: \PlanExercise.planDay)
    var exercises: [PlanExercise] = []

    /// Every session that was logged from this template.
    ///
    /// Nullify, never cascade: deleting a plan must not erase the user's workout history.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutDay.planDay)
    var loggedDays: [WorkoutDay] = []

    init(
        name: String = "",
        order: Int = 0,
        plan: WorkoutPlan? = nil
    ) {
        self.name = name
        self.order = order
        self.plan = plan
    }

    /// Times a week this day is trained (1–7).
    var timesPerWeek: Int {
        get { min(max(weeklyFrequency ?? 1, 1), 7) }
        set { weeklyFrequency = newValue }
    }

    var orderedExercises: [PlanExercise] {
        exercises.sorted { $0.order < $1.order }
    }
}
