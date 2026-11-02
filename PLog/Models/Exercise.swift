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

    /// The main primary muscle group. Stored directly as a `Codable` enum by SwiftData. It
    /// drives the exercise's colour and chip; further groups live in the two lists below.
    var category: MuscleGroup

    /// Primary groups beyond `category`, as `MuscleGroup` raw values. Strings rather than
    /// `[MuscleGroup]` so a value this build doesn't know is skipped instead of failing to load.
    var additionalPrimaryRawValues: [String] = []

    /// Secondary groups, as `MuscleGroup` raw values (same reasoning).
    var secondaryRawValues: [String] = []

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

extension Exercise {
    /// Every primary group, `category` first. The library lists the exercise under each one.
    var primaryMuscles: [MuscleGroup] {
        var groups = [category]
        for group in additionalPrimaryRawValues.compactMap(MuscleGroup.init(rawValue:)) where !groups.contains(group) {
            groups.append(group)
        }
        return groups
    }

    /// Secondary groups, never repeating a primary one. Shown on the exercise and counted as
    /// half a set in the muscle-group stats, but the library doesn't list the exercise there.
    var secondaryMuscles: [MuscleGroup] {
        let primary = primaryMuscles
        var groups: [MuscleGroup] = []
        for group in secondaryRawValues.compactMap(MuscleGroup.init(rawValue:))
        where !primary.contains(group) && !groups.contains(group) {
            groups.append(group)
        }
        return groups
    }

    /// Replaces the muscle groups. Keeps the current `category` as the main group while it's
    /// still primary, so its colour doesn't change under the user; otherwise the first
    /// primary in `MuscleGroup.allCases` order takes over. An empty `primary` is ignored.
    func setMuscles(primary: Set<MuscleGroup>, secondary: Set<MuscleGroup>) {
        let ordered = MuscleGroup.allCases.filter(primary.contains)
        guard let first = ordered.first else { return }
        let main = primary.contains(category) ? category : first
        category = main
        additionalPrimaryRawValues = ordered.filter { $0 != main }.map(\.rawValue)
        secondaryRawValues = MuscleGroup.allCases
            .filter { secondary.contains($0) && !primary.contains($0) }
            .map(\.rawValue)
    }
}
