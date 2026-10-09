//
//  SampleData.swift
//  PLog
//
//  An in-memory SwiftData container seeded with realistic data, used by SwiftUI previews
//  so every screen has something to render without touching the on-disk store.
//

import Foundation
import SwiftData

@MainActor
enum SampleData {
    /// A shared, in-memory container seeded once for previews.
    static let container: ModelContainer = {
        let schema = Schema([
            WorkoutDay.self,
            Exercise.self,
            ExerciseEntry.self,
            SetEntry.self,
            WorkoutPlan.self,
            PlanDay.self,
            PlanExercise.self,
            UserProfile.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            seed(into: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()

    /// Convenience accessor for the seeded context.
    static var context: ModelContext { container.mainContext }

    /// A sample exercise that has multiple sessions of history (good for charts).
    static var benchPress: Exercise {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == "Bench Press" }
        )
        return (try? context.fetch(descriptor))?.first ?? Exercise(name: "Bench Press", category: .chest)
    }

    /// The most recent seeded workout day.
    static var recentDay: WorkoutDay {
        let descriptor = FetchDescriptor<WorkoutDay>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor))?.first ?? WorkoutDay(name: "Push Day")
    }

    /// The seeded, currently active Push/Pull/Legs plan.
    static var plan: WorkoutPlan {
        let descriptor = FetchDescriptor<WorkoutPlan>()
        return (try? context.fetch(descriptor))?.first ?? WorkoutPlan(name: "Push / Pull / Legs")
    }

    /// The plan's "Push Day" template (has exercise slots).
    static var pushDay: PlanDay {
        plan.orderedDays.first ?? PlanDay(name: "Push Day")
    }

    // MARK: - Seeding

    private static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let today = Date()

        // Master exercise list.
        let bench = Exercise(name: "Bench Press", category: .chest)
        let squat = Exercise(name: "Back Squat", category: .legs)
        let row = Exercise(name: "Barbell Row", category: .back)
        let ohp = Exercise(name: "Overhead Press", category: .shoulders)
        let curl = Exercise(name: "Bicep Curl", category: .biceps)
        [bench, squat, row, ohp, curl].forEach(context.insert)

        // An active Push/Pull/Legs plan, started three weeks ago, so the log shows rest days.
        let planStart = calendar.date(byAdding: .day, value: -21, to: today) ?? today
        let plan = WorkoutPlan(name: "Push / Pull / Legs", startedAt: planStart)
        context.insert(plan)

        let pushDay = PlanDay(name: "Push Day", order: 0, plan: plan)
        let pullDay = PlanDay(name: "Pull Day", order: 1, plan: plan)
        let legDayTemplate = PlanDay(name: "Leg Day", order: 2, plan: plan)
        [pushDay, pullDay, legDayTemplate].forEach(context.insert)

        let slots: [(Exercise, PlanDay, Int, Int, Int)] = [
            (bench, pushDay, 0, 3, 8),
            (ohp, pushDay, 1, 3, 10),
            (row, pullDay, 0, 3, 8),
            (curl, pullDay, 1, 3, 12),
            (squat, legDayTemplate, 0, 4, 5),
        ]
        // Pull Day's row and curl are a superset, so previews show one.
        let pullSuperset = UUID()
        for (exercise, day, order, sets, reps) in slots {
            context.insert(PlanExercise(
                exercise: exercise,
                planDay: day,
                order: order,
                targetSets: sets,
                targetReps: reps,
                supersetID: day === pullDay ? pullSuperset : nil
            ))
        }

        // Three "push" sessions showing steady progression on the bench press.
        let pushProgressions: [(daysAgo: Int, weight: Double, reps: Int)] = [
            (daysAgo: 14, weight: 60, reps: 8),
            (daysAgo: 7, weight: 62.5, reps: 8),
            (daysAgo: 1, weight: 62.5, reps: 9),
        ]

        for progression in pushProgressions {
            let date = calendar.date(byAdding: .day, value: -progression.daysAgo, to: today) ?? today
            let day = WorkoutDay(date: date, name: "Push Day", notes: "", planDay: pushDay)
            context.insert(day)

            let benchEntry = ExerciseEntry(exercise: bench, workoutDay: day, order: 0)
            context.insert(benchEntry)
            for setNumber in 1...3 {
                let set = SetEntry(
                    setNumber: setNumber,
                    weight: progression.weight,
                    reps: progression.reps,
                    entry: benchEntry
                )
                context.insert(set)
            }
            // A drop set off the last set, so previews show one.
            let drop = SetEntry(
                setNumber: 4,
                weight: progression.weight - 12.5,
                reps: progression.reps,
                isDrop: true,
                entry: benchEntry
            )
            context.insert(drop)

            let ohpEntry = ExerciseEntry(exercise: ohp, workoutDay: day, order: 1)
            context.insert(ohpEntry)
            for setNumber in 1...3 {
                let set = SetEntry(
                    setNumber: setNumber,
                    weight: 40,
                    reps: 10,
                    entry: ohpEntry
                )
                context.insert(set)
            }
        }

        // A leg session for variety on the home screen.
        let legDate = calendar.date(byAdding: .day, value: -3, to: today) ?? today
        let legDay = WorkoutDay(date: legDate, name: "Leg Day", notes: "Felt strong", planDay: legDayTemplate)
        context.insert(legDay)
        let squatEntry = ExerciseEntry(exercise: squat, workoutDay: legDay, order: 0)
        context.insert(squatEntry)
        for setNumber in 1...4 {
            let set = SetEntry(
                setNumber: setNumber,
                weight: 100,
                reps: 5,
                rpe: 8,
                entry: squatEntry
            )
            context.insert(set)
        }

        UserProfile.ensureExists(in: context)
        try? context.save()
    }
}
