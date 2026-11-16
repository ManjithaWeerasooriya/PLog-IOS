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
    /// 2 added `SetRecord.isDrop`; 3 added `supersetID` on entries and plan slots; 4 added
    /// the Progress `dashboard` layout; 5 added each widget's `size`; 6 added each exercise's
    /// extra primary and secondary muscle groups; 7 added how many times a week each plan day runs;
    /// 8 added the weight unit the numbers are in and the body-weight log.
    /// An older app refuses a newer file rather
    /// than silently dropping what it can't represent.
    static let currentVersion = 8

    var version: Int = PLogBackup.currentVersion
    var exportedAt: Date
    var profile: ProfileRecord
    var exercises: [ExerciseRecord]
    var plans: [PlanRecord]
    var workouts: [WorkoutRecord]
    /// Absent before version 4 — restored as the default layout.
    var dashboard: [DashboardWidgetRecord]?
    /// A `WeightUnit` raw value: the unit every weight in the file is in. Absent before
    /// version 8, when the app only knew kilograms — read as "leave the setting alone".
    var weightUnit: String?
    /// Absent before version 8 — read as an empty log.
    var bodyWeights: [BodyWeightRecord]?

    nonisolated struct BodyWeightRecord: Codable {
        var date: Date
        var weight: Double
    }

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
        /// Absent before version 6 — read as none. Unknown raw values are dropped.
        var additionalPrimary: [String]?
        var secondary: [String]?
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
        /// Absent before version 7 (and when never set) — once a week.
        var timesPerWeek: Int?
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

    nonisolated struct DashboardWidgetRecord: Codable {
        /// A `DashboardWidgetKind` raw value; kinds this build doesn't know are skipped.
        var kind: String
        var order: Int
        /// Weeks of the widget's range; 1 is Muscle Groups' "this week" (an older build reads
        /// that as its default range).
        var rangeWeeks: Int
        var exerciseID: UUID?
        /// A `DashboardWidgetSize` raw value. Absent before version 5 — and an unknown or
        /// unsupported value — reads as the kind's default size.
        var size: String?
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
        let dashboard = try context.fetch(FetchDescriptor<Dashboard>()).first
        let bodyWeights = try context.fetch(FetchDescriptor<BodyWeightEntry>(sortBy: [SortDescriptor(\.date)]))

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
                    additionalPrimary: exercise.additionalPrimaryRawValues,
                    secondary: exercise.secondaryRawValues,
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
                            timesPerWeek: day.weeklyFrequency,
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
            },
            dashboard: dashboard?.orderedWidgets.map { widget in
                .init(
                    kind: widget.kindRawValue,
                    order: widget.order,
                    rangeWeeks: widget.rangeWeeks,
                    exerciseID: widget.exercise.flatMap { exerciseIDs[$0.persistentModelID] },
                    size: widget.size.rawValue
                )
            },
            weightUnit: WeightUnit.current.rawValue,
            bodyWeights: bodyWeights.map { .init(date: $0.date, weight: $0.weight) }
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
    /// must have confirmed the wipe. The profile and dashboard rows are updated in place so the
    /// singleton guarantees from `UserProfile`/`Dashboard.ensureExists` hold throughout.
    ///
    /// Never half-done: everything that can fail (reading the current rows) happens before
    /// the first change, and the replace itself can't throw, so the context is either
    /// untouched or fully replaced when the one save at the end runs. A partial replace is
    /// the state that must never reach disk — the old code fetched and deleted in turns, so
    /// a failed fetch midway left one, and autosave would have written it.
    /// (`context.rollback()` isn't the answer here: it traps in SwiftData when the context
    /// holds cascade-deleted rows that were never faulted in, which an import always does.)
    static func restore(_ backup: PLogBackup, into context: ModelContext, defaults: UserDefaults = .standard) throws {
        let current = try CurrentContents(in: context)
        replaceContents(current, with: backup, in: context)
        try context.save()
        // The numbers are in the unit they were exported in; show them that way.
        if let unit = backup.weightUnit.flatMap(WeightUnit.init(rawValue:)) {
            defaults.set(unit.rawValue, forKey: WeightUnit.storageKey)
        }
    }

    /// Every row an import replaces, read up front.
    struct CurrentContents {
        let dashboard: Dashboard?
        let profile: UserProfile?
        let workouts: [WorkoutDay]
        let plans: [WorkoutPlan]
        let exercises: [Exercise]
        let bodyWeights: [BodyWeightEntry]

        init(in context: ModelContext) throws {
            dashboard = try context.fetch(FetchDescriptor<Dashboard>()).first
            profile = try context.fetch(FetchDescriptor<UserProfile>()).first
            workouts = try context.fetch(FetchDescriptor<WorkoutDay>())
            plans = try context.fetch(FetchDescriptor<WorkoutPlan>())
            exercises = try context.fetch(FetchDescriptor<Exercise>())
            bodyWeights = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        }
    }

    /// The replace itself. Deliberately not `throws`: see `restore`.
    static func replaceContents(_ current: CurrentContents, with backup: PLogBackup, in context: ModelContext) {
        let dashboard = current.dashboard ?? {
            let created = Dashboard()
            context.insert(created)
            return created
        }()
        let oldWidgets = dashboard.widgets
        dashboard.widgets.removeAll()
        for widget in oldWidgets {
            context.delete(widget)
        }

        // Sessions first, then plans, then exercises: the cascade/nullify rules mean
        // nothing later in this order still points at something deleted earlier.
        for day in current.workouts { context.delete(day) }
        for plan in current.plans { context.delete(plan) }
        for exercise in current.exercises { context.delete(exercise) }
        for reading in current.bodyWeights { context.delete(reading) }

        let profile = current.profile ?? {
            let created = UserProfile()
            context.insert(created)
            return created
        }()
        profile.name = backup.profile.name
        profile.age = backup.profile.age
        profile.gender = Gender(rawValue: backup.profile.gender) ?? .female
        profile.heightCm = backup.profile.heightCm
        profile.weightKg = backup.profile.weightKg.map { max($0, 0) }
        for record in backup.bodyWeights ?? [] where record.weight > 0 {
            context.insert(BodyWeightEntry(date: record.date, weight: record.weight))
        }

        var exercisesByID: [UUID: Exercise] = [:]
        for record in backup.exercises {
            let exercise = Exercise(
                name: record.name,
                category: MuscleGroup(rawValue: record.category) ?? .other,
                notes: record.notes,
                createdAt: record.createdAt
            )
            exercise.additionalPrimaryRawValues = (record.additionalPrimary ?? []).filter { MuscleGroup(rawValue: $0) != nil }
            exercise.secondaryRawValues = (record.secondary ?? []).filter { MuscleGroup(rawValue: $0) != nil }
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
                day.weeklyFrequency = dayRecord.timesPerWeek.map { min(max($0, 1), 7) }
                context.insert(day)
                plan.days.append(day)
                planDaysByID[dayRecord.id] = day
                for slotRecord in dayRecord.exercises {
                    let slot = PlanExercise(
                        exercise: slotRecord.exerciseID.flatMap { exercisesByID[$0] },
                        order: slotRecord.order,
                        targetSets: max(slotRecord.targetSets, 0),
                        targetReps: max(slotRecord.targetReps, 0),
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
                        // A hand-edited or damaged file can't put impossible numbers in the log.
                        weight: setRecord.weight.isFinite ? max(setRecord.weight, 0) : 0,
                        reps: max(setRecord.reps, 0),
                        rpe: setRecord.rpe.map { min(max($0, 0), 10) },
                        notes: setRecord.notes,
                        isDrop: setRecord.isDrop ?? false
                    )
                    context.insert(set)
                    entry.sets.append(set)
                }
            }
        }

        if let records = backup.dashboard {
            for (index, record) in records.sorted(by: { $0.order < $1.order }).enumerated() {
                guard let kind = DashboardWidgetKind(rawValue: record.kind) else { continue }
                let widget = DashboardWidget(
                    kind: kind,
                    order: index,
                    range: AnalyticsRange(rawValue: record.rangeWeeks) ?? .twelveWeeks,
                    size: record.size.flatMap(DashboardWidgetSize.init(rawValue:)),
                    exercise: record.exerciseID.flatMap { exercisesByID[$0] }
                )
                // Muscle Groups' "this week" is stored as 1, which isn't an `AnalyticsRange`.
                if kind == .muscleSplit, let period = MuscleSplitPeriod(weeks: record.rangeWeeks) {
                    widget.muscleSplitPeriod = period
                }
                context.insert(widget)
                dashboard.widgets.append(widget)
            }
        } else {
            dashboard.addDefaultWidgets(in: context)
        }
        // Store the order as the grid draws it (sizes can pull a small widget up).
        for (index, widget) in DashboardLayout.packedOrder(dashboard.orderedWidgets).enumerated() {
            widget.order = index
        }
    }
}
