//
//  DebugHistory.swift
//  PLog
//
//  Debug builds only: fills the store with about two years of plausible training history
//  (four sessions a week, rotating through a plan's days, weights creeping up over time) so
//  slow paths show up the way they would for a long-time user. Reached from Settings.
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum DebugHistory {
    /// Logs sessions on four days a week for `weeks` weeks ending yesterday, using the
    /// active plan (or any plan with days). Returns how many sessions it added.
    @discardableResult
    static func generate(weeks: Int = 104, in context: ModelContext) -> Int {
        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        guard let plan = plans.first(where: \.isActive) ?? plans.first(where: { !$0.days.isEmpty }) else {
            return 0
        }
        let days = plan.orderedDays.filter { !$0.exercises.isEmpty }
        guard !days.isEmpty else { return 0 }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Mon, Tue, Thu, Sat-ish: offsets within each week.
        let trainingOffsets = [0, 1, 3, 5]
        var rotation = 0
        var added = 0

        for weekIndex in 0..<weeks {
            let weeksAgo = weeks - weekIndex
            guard let weekStart = calendar.date(byAdding: .day, value: -7 * weeksAgo, to: today) else { continue }
            // 0 at the start of the history, 1 at the end: weights rise about 25% over it.
            let progress = Double(weekIndex) / Double(max(weeks - 1, 1))

            for offset in trainingOffsets {
                guard
                    let date = calendar.date(byAdding: .day, value: offset, to: weekStart),
                    date < today,
                    let time = calendar.date(byAdding: .hour, value: 18, to: date)
                else { continue }

                let planDay = days[rotation % days.count]
                rotation += 1
                let session = WorkoutDay(date: time, name: planDay.name, planDay: planDay)
                context.insert(session)

                for (order, slot) in planDay.orderedExercises.enumerated() {
                    let entry = ExerciseEntry(exercise: slot.exercise, order: order, supersetID: slot.supersetID)
                    context.insert(entry)
                    session.entries.append(entry)

                    let base = baseWeight(for: slot.exercise?.name ?? "") * (1 + 0.25 * progress)
                    for setNumber in 1...max(slot.targetSets, 1) {
                        // A little back-off on later sets, and some session-to-session noise.
                        let noise = Double((weekIndex * 7 + setNumber * 3 + order) % 5 - 2) * 1.25
                        let weight = ((base - Double(setNumber - 1) * 2.5 + noise) / 2.5).rounded() * 2.5
                        let set = SetEntry(setNumber: setNumber, weight: max(weight, 2.5), reps: slot.targetReps)
                        context.insert(set)
                        entry.sets.append(set)
                    }
                }
                added += 1
            }
        }
        try? context.save()
        return added
    }

    /// A rough starting working weight for the starter library's exercises.
    private static func baseWeight(for name: String) -> Double {
        switch name {
        case "Deadlift": 120
        case "Back Squat", "Leg Press": 100
        case "Bench Press", "Romanian Deadlift": 70
        case "Barbell Row": 60
        case "Overhead Press", "Lat Pulldown", "Seated Cable Row": 45
        case "Incline Dumbbell Press", "Leg Curl", "Calf Raise": 30
        case "Tricep Pushdown", "Face Pull", "Cable Fly": 20
        default: 12.5
        }
    }
}
#endif
