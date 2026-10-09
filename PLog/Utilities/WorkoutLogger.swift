//
//  WorkoutLogger.swift
//  PLog
//
//  Stamps a plan-day template into a logged session. Shared by the Logs tab and the plan's
//  own log screen so both create sessions the same way.
//

import Foundation
import SwiftData

enum WorkoutLogger {
    /// The template to suggest next: the one after the most recently logged day in the
    /// plan's rotation (wrapping), or the first day if nothing has been logged yet.
    static func suggestedNextDay(in plan: WorkoutPlan) -> PlanDay? {
        let ordered = plan.orderedDays
        guard !ordered.isEmpty else { return nil }
        let lastLogged = ordered
            .flatMap(\.loggedDays)
            .max { $0.date < $1.date }
        guard
            let lastDay = lastLogged?.planDay,
            let index = ordered.firstIndex(where: { $0 === lastDay })
        else { return ordered.first }
        return ordered[(index + 1) % ordered.count]
    }

    /// Creates a `WorkoutDay` from a template: one entry per exercise slot, each with
    /// `targetSets` sets at `targetReps`, and each set's weight prefilled from the
    /// same-numbered set last session (falling back to the top set) — so the user only has
    /// to adjust weights, and a back-off set comes in at its usual load.
    ///
    /// Relationships are appended from the to-many side so Observation fires on the parents.
    @discardableResult
    static func logWorkout(
        for planDay: PlanDay,
        on date: Date = .now,
        in context: ModelContext
    ) -> WorkoutDay {
        let day = WorkoutDay(date: date, name: planDay.name)
        context.insert(day)
        planDay.loggedDays.append(day)

        for (order, slot) in planDay.orderedExercises.enumerated() {
            guard let exercise = slot.exercise else { continue }
            let entry = ExerciseEntry(exercise: exercise, order: order, supersetID: slot.supersetID)
            context.insert(entry)
            day.entries.append(entry)

            let previousSets = WorkoutHistory.previousSets(for: exercise, excluding: entry)
            let topWeight = WorkoutHistory.previousTopSet(for: exercise, excluding: entry)?.weight ?? 0
            for setNumber in stride(from: 1, through: slot.targetSets, by: 1) {
                let index = setNumber - 1
                let weight = previousSets.indices.contains(index) ? previousSets[index].weight : topWeight
                let set = SetEntry(
                    setNumber: setNumber,
                    weight: weight,
                    reps: slot.targetReps
                )
                context.insert(set)
                entry.sets.append(set)
            }
        }
        // A skipped slot (its exercise was deleted) can leave a superset partner on its own.
        Supersets.normalize(day.orderedEntries)

        try? context.save()
        return day
    }
}
