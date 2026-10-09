//
//  WorkoutPlanViewModel.swift
//  PLog
//
//  Owns the mutations for one plan: start/end lifecycle, day-template management, and
//  stamping a `WorkoutDay` out of a template so the user doesn't add exercises one by one.
//

import Foundation
import SwiftData

@MainActor
@Observable
final class WorkoutPlanViewModel {
    let plan: WorkoutPlan

    private let context: ModelContext

    init(plan: WorkoutPlan, context: ModelContext) {
        self.plan = plan
        self.context = context
    }

    var days: [PlanDay] { plan.orderedDays }

    /// The template to suggest next in the rotation.
    var suggestedNextDay: PlanDay? {
        WorkoutLogger.suggestedNextDay(in: plan)
    }

    // MARK: - Lifecycle

    /// Starts (or restarts) the plan. Only one plan runs at a time, so any other active plan
    /// is ended first.
    func start() {
        let allPlans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        for other in allPlans where other !== plan && other.isActive {
            other.endedAt = .now
        }
        plan.startedAt = .now
        plan.endedAt = nil
        save()
    }

    func end() {
        plan.endedAt = .now
        save()
    }

    // MARK: - Day templates

    // Relationship mutations go through the to-many side (`plan.days.append`) rather than
    // setting the inverse (`day.plan = plan`): only the former fires Observation on the plan,
    // so views reading `plan.days` refresh.

    @discardableResult
    func addDay(named name: String) -> PlanDay {
        let day = PlanDay(name: name, order: plan.days.count)
        context.insert(day)
        plan.days.append(day)
        save()
        return day
    }

    func removeDays(at offsets: IndexSet) {
        let ordered = days
        for index in offsets {
            let day = ordered[index]
            plan.days.removeAll { $0 === day }
            context.delete(day)
        }
        renumber(ordered.enumerated().filter { !offsets.contains($0.offset) }.map(\.element))
        save()
    }

    /// Persists a new rotation order. The view does the `move(fromOffsets:)` (a SwiftUI API).
    func reorderDays(_ ordered: [PlanDay]) {
        renumber(ordered)
        save()
    }

    private func renumber(_ ordered: [PlanDay]) {
        for (index, day) in ordered.enumerated() {
            day.order = index
        }
    }

    // MARK: - Logging

    /// Stamps a template into a new session. See `WorkoutLogger.logWorkout`.
    @discardableResult
    func logWorkout(for planDay: PlanDay, on date: Date = .now) -> WorkoutDay {
        WorkoutLogger.logWorkout(for: planDay, on: date, in: context)
    }

    func save() {
        try? context.save()
    }

    // MARK: - Duplication

    /// Copies a plan's full structure (days, exercise slots, targets) into a new, inactive
    /// plan named "<base> (n)" — the original is untouched and never started/ended.
    @discardableResult
    static func duplicate(_ plan: WorkoutPlan, in context: ModelContext) -> WorkoutPlan {
        let allNames = ((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []).map(\.name)
        let copy = WorkoutPlan(name: nextCopyName(for: plan.name, existing: allNames), notes: plan.notes)
        context.insert(copy)

        for day in plan.orderedDays {
            let dayCopy = PlanDay(name: day.name, order: day.order)
            context.insert(dayCopy)
            copy.days.append(dayCopy)

            for slot in day.orderedExercises {
                let slotCopy = PlanExercise(
                    exercise: slot.exercise,
                    order: slot.order,
                    targetSets: slot.targetSets,
                    targetReps: slot.targetReps,
                    supersetID: slot.supersetID
                )
                context.insert(slotCopy)
                dayCopy.exercises.append(slotCopy)
            }
        }

        try? context.save()
        return copy
    }

    /// "PPL" -> "PPL (1)"; if "PPL (1)" is taken, "PPL (2)"; duplicating "PPL (1)" itself
    /// still starts from base name "PPL" rather than compounding to "PPL (1) (1)".
    private static func nextCopyName(for name: String, existing: [String]) -> String {
        let base = baseName(from: name)
        var n = 1
        while existing.contains("\(base) (\(n))") {
            n += 1
        }
        return "\(base) (\(n))"
    }

    private static func baseName(from name: String) -> String {
        guard name.hasSuffix(")"), let openParen = name.lastIndex(of: "(") else { return name }
        let inner = name[name.index(after: openParen)..<name.index(before: name.endIndex)]
        guard !inner.isEmpty, inner.allSatisfy(\.isNumber) else { return name }
        let base = name[..<openParen].trimmingCharacters(in: .whitespaces)
        return base.isEmpty ? name : base
    }
}
