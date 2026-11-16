//
//  AppStore.swift
//  PLog
//
//  The one list of SwiftData models, and opening the on-disk store without crashing when
//  that fails. `PLogApp`, `SampleData` and the tests all build their containers from
//  `AppStore.schema`, so a new `@Model` is added in exactly one place.
//

import Foundation
import SwiftData
import OSLog

@MainActor
enum AppStore {
    /// Every `@Model` class. Add new ones here.
    static let models: [any PersistentModel.Type] = [
        WorkoutDay.self,
        Exercise.self,
        ExerciseEntry.self,
        SetEntry.self,
        WorkoutPlan.self,
        PlanDay.self,
        PlanExercise.self,
        UserProfile.self,
        Dashboard.self,
        DashboardWidget.self,
        BodyWeightEntry.self,
    ]

    static var schema: Schema { Schema(models) }

    /// An in-memory container, for previews and tests.
    static func inMemoryContainer() throws -> ModelContainer {
        let schema = schema
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
    }

    enum Launch {
        case ready(ModelContainer)
        /// The store couldn't be opened. Nothing was deleted; the message says what failed.
        case failed(String)
    }

    /// Opens the on-disk store and runs the launch-time guarantees. A failure is returned
    /// rather than trapped: a `fatalError` here would crash on every launch with no way for
    /// the user to see why or to keep their data.
    static func open() -> Launch {
        do {
            let container = try ModelContainer(for: schema)
            let context = container.mainContext
            // First launch only: the starter exercise library. A store that had no exercises
            // but does have plans or sessions (someone deleted their whole library) is
            // reseeded too, but it isn't a new install.
            let seeded = StarterData.seedIfNeeded(in: context)
            let hasHistory = ((try? context.fetchCount(FetchDescriptor<WorkoutDay>())) ?? 0) > 0
                || ((try? context.fetchCount(FetchDescriptor<WorkoutPlan>())) ?? 0) > 0
            let isFreshInstall = seeded && !hasHistory
            WeightUnit.chooseDefaultIfUnset(isFreshInstall: isFreshInstall)
            Onboarding.noteLaunch(isFreshInstall: isFreshInstall)
            // Always: exactly one UserProfile row, and the Progress layout (seeded with the
            // default widgets for new and pre-widget stores alike).
            UserProfile.ensureExists(in: context)
            Dashboard.ensureExists(in: context)
            return .ready(container)
        } catch {
            Log.data.error("Could not open the store: \(String(describing: error), privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }
}

/// Shared loggers. Failures that used to be swallowed by `try?` are written here.
nonisolated enum Log {
    static let data = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PLog", category: "data")
}

extension ModelContext {
    /// Saves, logging a failure instead of discarding it. The app autosaves constantly and
    /// has no screen to report a failed save on; the log is what makes one diagnosable.
    func saveLogged(function: StaticString = #function) {
        do {
            try save()
        } catch {
            Log.data.error("Save failed in \(function, privacy: .public): \(String(describing: error), privacy: .public)")
        }
    }
}
