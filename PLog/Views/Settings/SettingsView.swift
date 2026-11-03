//
//  SettingsView.swift
//  PLog
//
//  Settings, presented as a sheet from the Train tab's profile button: appearance, body
//  weight, and data export/import.
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

/// Split out so `@Bindable` can attach to a guaranteed non-optional `UserProfile`.
private struct SettingsForm: View {
    @Bindable var profile: UserProfile

    /// Same `UserDefaults` key `PLogApp` reads — `@AppStorage` keeps this picker and the
    /// live app appearance in sync without any manual plumbing.
    @AppStorage("appTheme") private var appTheme = AppTheme.system

    var body: some View {
        Form {
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

            // Only the field a feature actually reads (Analytics' body-weight card). Name,
            // gender, age and height are still persisted on `UserProfile` for backups, but
            // nothing displays them, so they aren't asked for.
            Section("Body") {
                NumberStepper(title: "Weight", value: weightBinding, step: 0.5, range: 30...300, unit: "kg", style: .row)
            }

            DataTransferSection()

            #if DEBUG
            DebugSection()
            #endif
        }
        .onAppear(perform: seedDefaultsIfNeeded)
    }

    // MARK: - Optional <-> stepper bindings

    /// Seeds a sensible starting value the first time Settings is opened, so the stepper never
    /// silently disagrees with the (still-nil) model — see `UserProfile.weightKg`'s doc comment.
    private func seedDefaultsIfNeeded() {
        if profile.weightKg == nil { profile.weightKg = 70 }
    }

    private var weightBinding: Binding<Double> {
        Binding(get: { profile.weightKg ?? 70 }, set: { profile.weightKg = $0 })
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
