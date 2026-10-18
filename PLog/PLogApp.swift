//
//  PLogApp.swift
//  PLog
//
//  Created by Manjitha Weerasooriya on 2026-09-16.
//

import SwiftUI
import SwiftData

@main
struct PLogApp: App {
    /// The user's light/dark mode preference, set in Settings. Shared with `SettingsView`
    /// via the same `UserDefaults` key rather than a binding — `@AppStorage` keeps both in
    /// sync automatically.
    @AppStorage("appTheme") private var appTheme = AppTheme.system

    /// The app-wide SwiftData container. Listing every model is explicit and future-proof;
    /// SwiftData wires up the relationships from here.
    let container: ModelContainer = {
        let schema = Schema([
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
        ])
        do {
            let container = try ModelContainer(for: schema)
            // First launch only: a starter exercise library and sample plans to log against.
            StarterData.seedIfNeeded(in: container.mainContext)
            // Always: guarantees exactly one UserProfile row exists for Settings to edit.
            UserProfile.ensureExists(in: container.mainContext)
            // Always: the Progress layout, seeded with the default widgets for new and
            // pre-widget stores alike.
            Dashboard.ensureExists(in: container.mainContext)
            return container
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(appTheme.colorScheme)
        }
        .modelContainer(container)
    }
}
