//
//  Exercise.swift
//  PLog
//
//  A reusable, master-list exercise (e.g. "Bench Press"). Not tied to a single day —
//  each time it is logged, an `ExerciseEntry` references back to this record.
//

import Foundation
import SwiftData

@Model
final class Exercise {
    /// Display name, e.g. "Bench Press". Unique in practice, enforced at the UI level.
    var name: String

    /// Muscle-group category. Stored directly as a `Codable` enum by SwiftData.
    var category: MuscleGroup

    /// Optional freeform notes about form cues, machine settings, etc.
    var notes: String

    /// When this exercise was added to the master list.
    var createdAt: Date

    /// Every logged occurrence of this exercise across all workout days.
    ///
    /// The inverse lives on `ExerciseEntry.exercise`. We do NOT cascade-delete here:
    /// removing an exercise from the master list should not silently wipe historical logs.
    @Relationship(inverse: \ExerciseEntry.exercise)
    var entries: [ExerciseEntry] = []

    /// Plan-template slots that reference this exercise. Nullified on delete, same reasoning.
    @Relationship(inverse: \PlanExercise.exercise)
    var planExercises: [PlanExercise] = []

    /// Exercise Progress widgets tracking this exercise. Nullified on delete.
    @Relationship(inverse: \DashboardWidget.exercise)
    var dashboardWidgets: [DashboardWidget] = []

    init(
        name: String,
        category: MuscleGroup = .other,
        notes: String = "",
        createdAt: Date = .now
    ) {
        self.name = name
        self.category = category
        self.notes = notes
        self.createdAt = createdAt
    }
}
