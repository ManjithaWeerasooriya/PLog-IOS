//
//  DataBackup.swift
//  PLog
//
//  Exports the whole store to one JSON file and restores it again. The file is a plain,
//  version-stamped snapshot (not the SwiftData store) so it stays readable and survives
//  schema changes with a migration step rather than breaking outright.
//

import Foundation
import SwiftData

// MARK: - File format

/// The on-disk shape. Object graph links use export-time UUIDs — `PersistentIdentifier`s
/// are not stable across stores, so they're never written out.
nonisolated struct PLogBackup: Codable {
    /// 2 added `SetRecord.isDrop`; 3 added `supersetID` on entries and plan slots. An older
    /// app refuses a newer file rather than silently dropping what it can't represent.
    static let currentVersion = 3

    var version: Int = PLogBackup.currentVersion
    var exportedAt: Date
    var profile: ProfileRecord
    var exercises: [ExerciseRecord]
    var plans: [PlanRecord]
    var workouts: [WorkoutRecord]

    nonisolated struct ProfileRecord: Codable {
        var name: String
        var age: Int?
        var gender: String
        var heightCm: Double?
        var weightKg: Double?
    }

    nonisolated struct ExerciseRecord: Codable {
        var id: UUID
        var name: String
        var category: String
        var notes: String
        var createdAt: Date
    }

    nonisolated struct PlanRecord: Codable {
        var name: String
        var notes: String
        var createdAt: Date
        var startedAt: Date?
        var endedAt: Date?
        var days: [PlanDayRecord]
    }

    nonisolated struct PlanDayRecord: Codable {
        var id: UUID
        var name: String
        var order: Int
        var exercises: [PlanExerciseRecord]
    }

    nonisolated struct PlanExerciseRecord: Codable {
        var exerciseID: UUID?
        var order: Int
        var targetSets: Int
        var targetReps: Int
        /// Absent before version 3 — read as not in a superset.
        var supersetID: UUID?
    }

    nonisolated struct WorkoutRecord: Codable {
        var date: Date
        var name: String
        var notes: String
        var planDayID: UUID?
        var entries: [EntryRecord]
    }

    nonisolated struct EntryRecord: Codable {
        var exerciseID: UUID?
        var order: Int
        /// Absent before version 3 — read as not in a superset.
        var supersetID: UUID?
        var sets: [SetRecord]
    }

    nonisolated struct SetRecord: Codable {
        var setNumber: Int
        var weight: Double
        var reps: Int
        var rpe: Double?
        var notes: String?
        /// Absent in version 1 files, which predate drop sets — read as `false`.
        var isDrop: Bool?
    }

    var setCount: Int {
        workouts.reduce(0) { $0 + $1.entries.reduce(0) { $0 + $1.sets.count } }
    }
}

// MARK: - Export / import

enum DataBackup {
    enum ImportError: LocalizedError {
        case unreadableFile
        case notABackup
        case unsupportedVersion(Int)

        var errorDescription: String? {
            switch self {
            case .unreadableFile:
                return "The file couldn't be opened."
            case .notABackup:
                return "That file isn't a PLog backup."
            case .unsupportedVersion(let version):
                return "This backup (version \(version)) was made by a newer version of PLog. Update the app to import it."
            }
        }
    }

    static func suggestedFilename(for date: Date = .now) -> String {
        "PLog-Backup-\(date.formatted(.iso8601.year().month().day())).json"
    }

    /// Snapshots every row in the store as JSON.
    static func export(from context: ModelContext) throws -> Data {
        let exercises = try context.fetch(FetchDescriptor<Exercise>(sortBy: [SortDescriptor(\.createdAt)]))
        let plans = try context.fetch(FetchDescriptor<WorkoutPlan>(sortBy: [SortDescriptor(\.createdAt)]))
        let workouts = try context.fetch(FetchDescriptor<WorkoutDay>(sortBy: [SortDescriptor(\.date)]))
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first ?? UserProfile()

        var exerciseIDs: [PersistentIdentifier: UUID] = [:]
        for exercise in exercises {
            exerciseIDs[exercise.persistentModelID] = UUID()
        }
        var planDayIDs: [PersistentIdentifier: UUID] = [:]
        for day in plans.flatMap(\.days) {
            planDayIDs[day.persistentModelID] = UUID()
        }

        let backup = PLogBackup(
            exportedAt: .now,
            profile: .init(
                name: profile.name,
                age: profile.age,
                gender: profile.gender.rawValue,
                heightCm: profile.heightCm,
                weightKg: profile.weightKg
            ),
            exercises: exercises.compactMap { exercise in
                guard let id = exerciseIDs[exercise.persistentModelID] else { return nil }
                return .init(
                    id: id,
                    name: exercise.name,
                    category: exercise.category.rawValue,
                    notes: exercise.notes,
                    createdAt: exercise.createdAt
                )
            },
            plans: plans.map { plan in
                .init(
                    name: plan.name,
                    notes: plan.notes,
                    createdAt: plan.createdAt,
                    startedAt: plan.startedAt,
                    endedAt: plan.endedAt,
                    days: plan.orderedDays.compactMap { day in
                        guard let id = planDayIDs[day.persistentModelID] else { return nil }
                        return .init(
                            id: id,
                            name: day.name,
                            order: day.order,
                            exercises: day.orderedExercises.map { slot in
                                .init(
                                    exerciseID: slot.exercise.flatMap { exerciseIDs[$0.persistentModelID] },
                                    order: slot.order,
                                    targetSets: slot.targetSets,
                                    targetReps: slot.targetReps,
                                    supersetID: slot.supersetID
                                )
                            }
                        )
                    }
                )
            },
            workouts: workouts.map { day in
                .init(
                    date: day.date,
                    name: day.name,
                    notes: day.notes,
                    planDayID: day.planDay.flatMap { planDayIDs[$0.persistentModelID] },
                    entries: day.orderedEntries.map { entry in
                        .init(
                            exerciseID: entry.exercise.flatMap { exerciseIDs[$0.persistentModelID] },
                            order: entry.order,
                            supersetID: entry.supersetID,
                            sets: entry.orderedSets.map { set in
                                .init(
                                    setNumber: set.setNumber,
                                    weight: set.weight,
                                    reps: set.reps,
                                    rpe: set.rpe,
                                    notes: set.notes,
                                    isDrop: set.isDrop
                                )
                            }
                        )
                    }
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(backup)
    }

    /// Parses and validates a backup file without touching the store, so the UI can show
    /// what's about to be imported before the user confirms the replace.
    static func decode(_ data: Data) throws -> PLogBackup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: PLogBackup
        do {
            backup = try decoder.decode(PLogBackup.self, from: data)
        } catch {
            throw ImportError.notABackup
        }
        guard backup.version <= PLogBackup.currentVersion else {
            throw ImportError.unsupportedVersion(backup.version)
        }
        return backup
    }

    /// Replaces everything in the store with the backup's contents. Not a merge: the caller
    /// must have confirmed the wipe. The profile row is updated in place so the singleton
    /// guarantee from `UserProfile.ensureExists` holds throughout.
    static func restore(_ backup: PLogBackup, into context: ModelContext) throws {
        // Sessions first, then plans, then exercises: the cascade/nullify rules mean
        // nothing later in this order still points at something deleted earlier.
        for day in try context.fetch(FetchDescriptor<WorkoutDay>()) { context.delete(day) }
        for plan in try context.fetch(FetchDescriptor<WorkoutPlan>()) { context.delete(plan) }
        for exercise in try context.fetch(FetchDescriptor<Exercise>()) { context.delete(exercise) }

        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first ?? {
            let created = UserProfile()
            context.insert(created)
            return created
        }()
        profile.name = backup.profile.name
        profile.age = backup.profile.age
        profile.gender = Gender(rawValue: backup.profile.gender) ?? .female
        profile.heightCm = backup.profile.heightCm
        profile.weightKg = backup.profile.weightKg

        var exercisesByID: [UUID: Exercise] = [:]
        for record in backup.exercises {
            let exercise = Exercise(
                name: record.name,
                category: MuscleGroup(rawValue: record.category) ?? .other,
                notes: record.notes,
                createdAt: record.createdAt
            )
            context.insert(exercise)
            exercisesByID[record.id] = exercise
        }

        // Children are appended from the to-many side so the inverse is set and parents
        // observe the change — same rule as everywhere else (see AGENT.md).
        var planDaysByID: [UUID: PlanDay] = [:]
        for record in backup.plans {
            let plan = WorkoutPlan(
                name: record.name,
                notes: record.notes,
                createdAt: record.createdAt,
                startedAt: record.startedAt,
                endedAt: record.endedAt
            )
            context.insert(plan)
            for dayRecord in record.days {
                let day = PlanDay(name: dayRecord.name, order: dayRecord.order)
                context.insert(day)
                plan.days.append(day)
                planDaysByID[dayRecord.id] = day
                for slotRecord in dayRecord.exercises {
                    let slot = PlanExercise(
                        exercise: slotRecord.exerciseID.flatMap { exercisesByID[$0] },
                        order: slotRecord.order,
                        targetSets: slotRecord.targetSets,
                        targetReps: slotRecord.targetReps,
                        supersetID: slotRecord.supersetID
                    )
                    context.insert(slot)
                    day.exercises.append(slot)
                }
            }
        }

        for record in backup.workouts {
            let day = WorkoutDay(date: record.date, name: record.name, notes: record.notes)
            context.insert(day)
            if let planDay = record.planDayID.flatMap({ planDaysByID[$0] }) {
                planDay.loggedDays.append(day)
            }
            for entryRecord in record.entries {
                let entry = ExerciseEntry(
                    exercise: entryRecord.exerciseID.flatMap { exercisesByID[$0] },
                    order: entryRecord.order,
                    supersetID: entryRecord.supersetID
                )
                context.insert(entry)
                day.entries.append(entry)
                for setRecord in entryRecord.sets {
                    let set = SetEntry(
                        setNumber: setRecord.setNumber,
                        weight: setRecord.weight,
                        reps: setRecord.reps,
                        rpe: setRecord.rpe,
                        notes: setRecord.notes,
                        isDrop: setRecord.isDrop ?? false
                    )
                    context.insert(set)
                    entry.sets.append(set)
                }
            }
        }

        try context.save()
    }
}
