//
//  SettingsView.swift
//  PLog
//
//  Settings, presented as a sheet from the Train tab's profile button: weight unit and the
//  optional training extras, the body-weight log, appearance, and data export/import.
//  `UserProfile.ensureExists` guarantees a row already exists by the time this view appears,
//  so `profiles.first` is safe to treat as non-optional here (the one place in the app where
//  that's true by construction).
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            Group {
                if let profile {
                    form(for: profile)
                } else {
                    // Only reachable for an instant before UserProfile.ensureExists commits.
                    ProgressView()
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func form(for profile: UserProfile) -> some View {
        SettingsForm(profile: profile)
    }
}

/// Split out so it's only built once the profile row exists.
private struct SettingsForm: View {
    let profile: UserProfile

    @Environment(\.modelContext) private var context

    /// Same `UserDefaults` key `PLogApp` reads — `@AppStorage` keeps this picker and the
    /// live app appearance in sync without any manual plumbing.
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    @AppStorage(WeightUnit.storageKey) private var unit = WeightUnit.kg
    @AppStorage(EffortTracking.storageKey) private var tracksEffort = false
    @AppStorage(RestTimer.alertsKey) private var restAlerts = false

    /// A unit the user picked while weights are already logged, waiting on the choice
    /// between converting them and only relabelling.
    @State private var pendingUnit: WeightUnit?
    @State private var showingAlertsDenied = false
    @State private var errorMessage: String?
    @State private var libraryResult: String?

    var body: some View {
        Form {
            Section {
                Picker("Weight Unit", selection: unitSelection) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                Toggle("Reps in Reserve", isOn: $tracksEffort)
                Toggle("Rest Timer Alert", isOn: restAlertsSelection)
            } header: {
                Text("Training")
            } footer: {
                Text("Reps in Reserve adds a picker to each set for how many more reps you had left. The alert tells you rest is over when PLog isn't on screen.")
            }

            Section("Body") {
                NavigationLink {
                    BodyWeightView()
                } label: {
                    LabeledContent("Body Weight", value: profile.weightKg.map(unit.string) ?? "Not logged")
                }
            }

            Section("Appearance") {
                // .navigationLink rather than .segmented: "Use Device Theme" is too long a
                // label to sit comfortably in a 3-way segmented control on a phone-width row.
                Picker("Theme", selection: $appTheme) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section {
                Button {
                    let added = StarterData.addMissingExercises(in: context)
                    libraryResult = added == 0
                        ? "You already have every starter exercise."
                        : "Added \(added) \(added == 1 ? "exercise" : "exercises")."
                } label: {
                    Label("Add Starter Exercises", systemImage: "plus.rectangle.on.rectangle")
                }
            } header: {
                Text("Exercise Library")
            } footer: {
                Text(libraryResult ?? "Adds any of the \(StarterData.library.count) built-in exercises you don't have. Your own exercises aren't changed.")
            }

            DataTransferSection()

            #if DEBUG
            DebugSection()
            #endif
        }
        // `.alert`, not `.confirmationDialog` — see AGENT.md on destructive confirmations.
        .alert("Convert Your Logged Weights?", isPresented: isChoosingConversion, presenting: pendingUnit) { newUnit in
            Button("Convert to \(newUnit.symbol)") { changeUnit(to: newUnit, converting: true) }
            Button("Keep the Numbers") { changeUnit(to: newUnit, converting: false) }
            Button("Cancel", role: .cancel) { pendingUnit = nil }
        } message: { newUnit in
            Text("Your weights were logged as \(unit.symbol). Convert them to \(newUnit.symbol), or keep the numbers as they are and only change the label?")
        }
        .alert("Notifications Are Off", isPresented: $showingAlertsDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To get the rest timer alert, allow notifications for PLog in the Settings app.")
        }
        .alert("Something Went Wrong", isPresented: isShowingError) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Weight unit

    /// Changing the unit with weights already logged asks first: numbers entered as kg mean
    /// something else relabelled as lb, and only the user knows which they want.
    private var unitSelection: Binding<WeightUnit> {
        Binding(
            get: { unit },
            set: { newUnit in
                guard newUnit != unit else { return }
                if hasLoggedWeights {
                    pendingUnit = newUnit
                } else {
                    unit = newUnit
                }
            }
        )
    }

    private var hasLoggedWeights: Bool {
        if profile.weightKg != nil { return true }
        var descriptor = FetchDescriptor<SetEntry>(predicate: #Predicate { $0.weight > 0 })
        descriptor.fetchLimit = 1
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    private func changeUnit(to newUnit: WeightUnit, converting: Bool) {
        pendingUnit = nil
        if converting {
            do {
                try WeightUnit.convertStoredWeights(from: unit, to: newUnit, in: context)
            } catch {
                errorMessage = "Your weights couldn't be converted, so nothing was changed. \(error.localizedDescription)"
                return
            }
        }
        unit = newUnit
    }

    private var isChoosingConversion: Binding<Bool> {
        Binding(get: { pendingUnit != nil }, set: { if !$0 { pendingUnit = nil } })
    }

    private var isShowingError: Binding<Bool> {
        Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
    }

    // MARK: - Rest timer alert

    /// Turning the alert on is where notification permission is asked for; if it's refused
    /// the switch goes back off and says why.
    private var restAlertsSelection: Binding<Bool> {
        Binding(
            get: { restAlerts },
            set: { isOn in
                guard isOn else {
                    restAlerts = false
                    return
                }
                Task {
                    if await RestTimer.requestAlertPermission() {
                        restAlerts = true
                    } else {
                        restAlerts = false
                        showingAlertsDenied = true
                    }
                }
            }
        )
    }
}

#if DEBUG
/// Debug builds only: tools for reproducing performance problems with a long history.
private struct DebugSection: View {
    @Environment(\.modelContext) private var context
    @State private var result: String?

    var body: some View {
        Section {
            Button("Generate 2 Years of History") {
                let added = DebugHistory.generate(in: context)
                result = added > 0 ? "Added \(added) sessions." : "No plan with days to log from."
            }
        } header: {
            Text("Debug")
        } footer: {
            if let result { Text(result) }
        }
    }
}
#endif

#Preview {
    SettingsView()
        .modelContainer(SampleData.container)
}
