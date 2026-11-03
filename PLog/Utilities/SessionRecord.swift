//
//  SessionRecord.swift
//  PLog
//
//  A logged session copied into plain values — everything the Progress figures need from
//  it. The first read of each set through SwiftData is slow, and it's slow again after
//  every save (about 0.6 s to walk two years of sets), while the copies cost nothing to
//  re-read. `SessionRecordCache` keeps them and re-reads only the sessions a save touched.
//

import Foundation
import SwiftData

/// Anything with a session date, so the date-window helpers work on models and records alike.
protocol Dated {
    var date: Date { get }
}

extension WorkoutDay: Dated {}

struct SessionRecord: Dated {
    /// One exercise as performed in the session.
    struct Entry {
        let id: PersistentIdentifier
        /// `nil` when the exercise was deleted from the library.
        let exerciseID: PersistentIdentifier?
        /// Empty when the exercise was deleted, so the entry counts toward no group.
        let primaryMuscles: [MuscleGroup]
        let secondaryMuscles: [MuscleGroup]
        /// Working sets only — drops continue a set rather than count as one.
        let workingSets: Int
        /// Σ weight × reps over every set, drops included.
        let volume: Double
        /// The heaviest set.
        let topSet: SetSnapshot?
        let bestEstimatedOneRepMax: Double
        /// Lets the cache find this session from a saved set's identifier, even once the
        /// set is deleted.
        let setIDs: [PersistentIdentifier]

        init(_ entry: ExerciseEntry) {
            let sets = entry.sets
            id = entry.persistentModelID
            exerciseID = entry.exercise?.persistentModelID
            primaryMuscles = entry.exercise?.primaryMuscles ?? []
            secondaryMuscles = entry.exercise?.secondaryMuscles ?? []
            workingSets = entry.workingSets.count
            volume = entry.totalVolume
            topSet = sets.max(by: { $0.weight < $1.weight }).map { SetSnapshot(weight: $0.weight, reps: $0.reps) }
            bestEstimatedOneRepMax = sets
                .map { SetSnapshot(weight: $0.weight, reps: $0.reps).estimatedOneRepMax }
                .max() ?? 0
            setIDs = sets.map(\.persistentModelID)
        }
    }

    let id: PersistentIdentifier
    let date: Date
    let entries: [Entry]
    let volume: Double
    let workingSets: Int

    init(_ day: WorkoutDay) {
        id = day.persistentModelID
        date = day.date
        entries = day.entries.map { Entry($0) }
        volume = entries.reduce(0) { $0 + $1.volume }
        workingSets = entries.reduce(0) { $0 + $1.workingSets }
    }
}

extension ExerciseHistoryPoint {
    /// The one definition of a progress point, shared by `WorkoutHistory.historyPoints` and
    /// `DashboardStats` so the charts and the dashboard can't disagree.
    init(_ entry: SessionRecord.Entry, date: Date) {
        self.init(
            id: entry.id,
            date: date,
            topWeight: entry.topSet?.weight ?? 0,
            topSetReps: entry.topSet?.reps ?? 0,
            totalVolume: entry.volume,
            estimatedOneRepMax: entry.bestEstimatedOneRepMax
        )
    }
}

/// Keeps a `SessionRecord` per logged session between dashboard rebuilds, re-reading only
/// sessions that are new or that a save touched. Anything it can't place marks everything
/// stale, so a miss costs a full re-read, never a wrong figure.
@MainActor
final class SessionRecordCache {
    private var records: [PersistentIdentifier: SessionRecord] = [:]
    /// Entry and set identifiers → the session they belong to.
    private var owners: [PersistentIdentifier: PersistentIdentifier] = [:]
    private var stale: Set<PersistentIdentifier> = []
    private var allStale = false

    /// Saves that only touch the dashboard layout (a drag, a resize, a card's range).
    private static let layoutEntities: Set<String> = ["Dashboard", "DashboardWidget"]

    /// Records for `workouts`, in the same order.
    func records(for workouts: [WorkoutDay]) -> [SessionRecord] {
        if allStale {
            records = [:]
            allStale = false
        }
        var kept: [PersistentIdentifier: SessionRecord] = [:]
        let result = workouts.map { day in
            let id = day.persistentModelID
            let record = stale.contains(id) ? SessionRecord(day) : records[id] ?? SessionRecord(day)
            kept[id] = record
            return record
        }
        records = kept
        stale = []
        owners = [:]
        for record in result {
            for entry in record.entries {
                owners[entry.id] = record.id
                for setID in entry.setIDs { owners[setID] = record.id }
            }
        }
        return result
    }

    /// Marks the sessions a save touched. Returns whether the save can change any dashboard
    /// figure at all (layout-only saves can't).
    func noteSave(_ note: Notification, in context: ModelContext) -> Bool {
        let keys: [ModelContext.NotificationKey] = [.insertedIdentifiers, .updatedIdentifiers, .deletedIdentifiers]
        let changed = keys.map { note.userInfo?[$0.rawValue] as? [PersistentIdentifier] ?? [] }
        let deleted = Set(changed[2])
        let ids = changed.flatMap { $0 }
        guard !ids.isEmpty else {
            allStale = true
            return true
        }

        var affectsFigures = false
        for id in ids where !Self.layoutEntities.contains(id.entityName) {
            affectsFigures = true
            switch id.entityName {
            case "WorkoutDay":
                stale.insert(id)
            case "ExerciseEntry", "SetEntry":
                if let session = owners[id] ?? (deleted.contains(id) ? nil : session(of: id, in: context)) {
                    stale.insert(session)
                } else if !records.isEmpty {
                    allStale = true
                }
            case "Exercise":
                // Logging it also "updates" it (its entries list grew), so re-read the
                // sessions that log it only when its muscle groups actually changed.
                let exercise = deleted.contains(id) ? nil : context.model(for: id) as? Exercise
                let logged = records.values.filter { $0.entries.contains { $0.exerciseID == id } }
                let recorded = logged.first?.entries.first { $0.exerciseID == id }
                if let exercise, let recorded,
                   recorded.primaryMuscles == exercise.primaryMuscles,
                   recorded.secondaryMuscles == exercise.secondaryMuscles {
                    break
                }
                for record in logged { stale.insert(record.id) }
            default:
                // Plans and the profile feed the dashboard but not the records.
                break
            }
        }
        return affectsFigures
    }

    private func session(of id: PersistentIdentifier, in context: ModelContext) -> PersistentIdentifier? {
        switch context.model(for: id) {
        case let entry as ExerciseEntry: entry.workoutDay?.persistentModelID
        case let set as SetEntry: set.entry?.workoutDay?.persistentModelID
        default: nil
        }
    }
}
