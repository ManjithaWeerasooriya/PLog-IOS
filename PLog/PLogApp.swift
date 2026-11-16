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

    /// kg or lb. Read here and handed down through the environment so every screen,
    /// including sheets, redraws when it changes.
    @AppStorage(WeightUnit.storageKey) private var weightUnit = WeightUnit.kg

    /// The app-wide SwiftData container, or why it couldn't be opened — see `AppStore.open`.
    private let launch = AppStore.open()

    var body: some Scene {
        WindowGroup {
            Group {
                switch launch {
                case .ready(let container):
                    ContentView()
                        .modelContainer(container)
                case .failed(let message):
                    StoreUnavailableView(message: message)
                }
            }
            .environment(\.weightUnit, weightUnit)
            .preferredColorScheme(appTheme.colorScheme)
        }
    }
}

/// Shown instead of the app when the store can't be opened. Says what happened and that
/// nothing was deleted, which a crash on launch never could.
private struct StoreUnavailableView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("Can't Open Your Data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("PLog couldn't open its workout store, so it stopped rather than risk your data. Nothing has been deleted. Restart your iPhone and open PLog again; if you're low on storage, free some space first.\n\n\(message)")
        }
    }
}
