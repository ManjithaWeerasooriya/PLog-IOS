//
//  StarterData.swift
//  PLog
//
//  The starter exercise library, seeded the first time the app runs with an empty store so
//  there's something to log against straight away. Plans are no longer seeded: a new user
//  picks a ready-made program on the welcome sheet (see `PlanTemplate`) or builds their
//  own. Separate from `SampleData`, the in-memory preview fixture.
//

import Foundation
import SwiftData

@MainActor
enum StarterData {
    /// One library exercise: its name and muscle groups.
    struct Definition {
        let name: String
        let primary: Set<MuscleGroup>
        let secondary: Set<MuscleGroup>

        init(_ name: String, _ primary: Set<MuscleGroup>, _ secondary: Set<MuscleGroup> = []) {
            self.name = name
            self.primary = primary
            self.secondary = secondary
        }
    }

    /// Seeds only when the store has no exercises at all, so it never touches real data.
    /// Returns whether it seeded, which is how the app knows this is a brand-new install.
    @discardableResult
    static func seedIfNeeded(in context: ModelContext) -> Bool {
        let existing = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard existing == 0 else { return false }
        for definition in library {
            insert(definition, into: context)
        }
        context.saveLogged()
        return true
    }

    /// Adds every library exercise the store doesn't already have (matched by name, ignoring
    /// case), leaving existing ones exactly as they are. Returns how many it added.
    @discardableResult
    static func addMissingExercises(in context: ModelContext) -> Int {
        var known = existingNames(in: context)
        var added = 0
        for definition in library where !known.contains(key(definition.name)) {
            insert(definition, into: context)
            known.insert(key(definition.name))
            added += 1
        }
        if added > 0 { context.saveLogged() }
        return added
    }

    /// The store's exercise with this name, created from the library if it's missing, or as a
    /// plain "Other" exercise when the library doesn't know the name. Used by plan templates,
    /// so a program can be added to a store whose library has been edited.
    static func exercise(named name: String, in context: ModelContext, cache: inout [String: Exercise]) -> Exercise {
        if cache.isEmpty {
            let all = (try? context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
            for exercise in all where cache[key(exercise.name)] == nil {
                cache[key(exercise.name)] = exercise
            }
        }
        if let found = cache[key(name)] { return found }
        let definition = library.first { key($0.name) == key(name) } ?? Definition(name, [.other])
        let created = insert(definition, into: context)
        cache[key(name)] = created
        return created
    }

    @discardableResult
    private static func insert(_ definition: Definition, into context: ModelContext) -> Exercise {
        let exercise = Exercise(name: definition.name)
        exercise.setMuscles(primary: definition.primary, secondary: definition.secondary)
        context.insert(exercise)
        return exercise
    }

    private static func existingNames(in context: ModelContext) -> Set<String> {
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return Set(all.map { key($0.name) })
    }

    private static func key(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: - Library

    /// The common gym exercises, each under its most specific muscle group. Secondary groups
    /// count as half a set in the weekly-set figures, so they're listed only where the
    /// muscle does real work.
    static let library: [Definition] = [
        // Chest
        Definition("Bench Press", [.chest], [.triceps, .shoulders]),
        Definition("Incline Bench Press", [.chest], [.shoulders, .triceps]),
        Definition("Dumbbell Bench Press", [.chest], [.triceps, .shoulders]),
        Definition("Incline Dumbbell Press", [.chest], [.shoulders, .triceps]),
        Definition("Machine Chest Press", [.chest], [.triceps, .shoulders]),
        Definition("Cable Fly", [.chest]),
        Definition("Pec Deck", [.chest]),
        Definition("Push-Up", [.chest], [.triceps, .shoulders]),
        Definition("Dip", [.chest, .triceps], [.shoulders]),

        // Back
        Definition("Deadlift", [.back, .hamstrings], [.glutes, .traps, .forearms]),
        Definition("Barbell Row", [.back], [.biceps, .rearDelts]),
        Definition("Dumbbell Row", [.back], [.biceps, .rearDelts]),
        Definition("T-Bar Row", [.back], [.biceps, .rearDelts]),
        Definition("Chest-Supported Row", [.back], [.biceps, .rearDelts]),
        Definition("Seated Cable Row", [.back], [.biceps, .rearDelts]),
        Definition("Lat Pulldown", [.back], [.biceps]),
        Definition("Pull-Up", [.back], [.biceps, .forearms]),
        Definition("Chin-Up", [.back, .biceps], [.forearms]),
        Definition("Straight-Arm Pulldown", [.back]),

        // Shoulders
        Definition("Overhead Press", [.shoulders], [.triceps]),
        Definition("Dumbbell Shoulder Press", [.shoulders], [.triceps]),
        Definition("Machine Shoulder Press", [.shoulders], [.triceps]),
        Definition("Lateral Raise", [.shoulders]),
        Definition("Cable Lateral Raise", [.shoulders]),

        // Rear delts and traps
        Definition("Face Pull", [.rearDelts], [.traps]),
        Definition("Reverse Pec Deck", [.rearDelts], [.traps]),
        Definition("Rear Delt Fly", [.rearDelts]),
        Definition("Barbell Shrug", [.traps], [.forearms]),
        Definition("Dumbbell Shrug", [.traps], [.forearms]),

        // Arms
        Definition("Bicep Curl", [.biceps], [.forearms]),
        Definition("Hammer Curl", [.biceps], [.forearms]),
        Definition("Preacher Curl", [.biceps]),
        Definition("Incline Dumbbell Curl", [.biceps]),
        Definition("Cable Curl", [.biceps]),
        Definition("Tricep Pushdown", [.triceps]),
        Definition("Overhead Tricep Extension", [.triceps]),
        Definition("Skull Crusher", [.triceps]),
        Definition("Close-Grip Bench Press", [.triceps], [.chest, .shoulders]),
        Definition("Wrist Curl", [.forearms]),
        Definition("Reverse Curl", [.forearms], [.biceps]),

        // Legs
        Definition("Back Squat", [.quads, .glutes], [.hamstrings, .core]),
        Definition("Front Squat", [.quads], [.glutes, .core]),
        Definition("Hack Squat", [.quads], [.glutes]),
        Definition("Leg Press", [.quads], [.glutes]),
        Definition("Leg Extension", [.quads]),
        Definition("Bulgarian Split Squat", [.quads, .glutes], [.hamstrings]),
        Definition("Walking Lunge", [.quads, .glutes], [.hamstrings]),
        Definition("Romanian Deadlift", [.hamstrings], [.glutes, .back]),
        Definition("Leg Curl", [.hamstrings]),
        Definition("Seated Leg Curl", [.hamstrings]),
        Definition("Hip Thrust", [.glutes], [.hamstrings]),
        Definition("Cable Kickback", [.glutes]),
        Definition("Hip Abduction", [.glutes]),
        Definition("Calf Raise", [.calves]),
        Definition("Seated Calf Raise", [.calves]),

        // Core
        Definition("Plank", [.core]),
        Definition("Hanging Leg Raise", [.core]),
        Definition("Cable Crunch", [.core]),
        Definition("Ab Wheel Rollout", [.core]),
    ]
}
