//
//  WelcomeView.swift
//  PLog
//
//  The one screen a new user sees before the app: pick a program and a weight unit, and
//  the first workout is ready to log. Two decisions, both with a default, and Skip always
//  there — the point is to reach the first session, not to explain the app. Shown once, on
//  a brand-new install only (`Onboarding`).
//

import SwiftUI
import SwiftData

struct WelcomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(WeightUnit.storageKey) private var unit = WeightUnit.kg

    /// Full Body is preselected: three days is what most people starting out can keep to.
    @State private var selectedID = PlanTemplate.fullBody.id

    private var selected: PlanTemplate {
        PlanTemplate.all.first { $0.id == selectedID } ?? .fullBody
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Welcome to PLog")
                            .font(.largeTitle.weight(.bold))
                        Text("Choose a program and your first workout is ready to log. PLog shows what you lifted last time and whether you beat it.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(PlanTemplate.all) { template in
                        Button {
                            selectedID = template.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: template.id == selectedID ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(template.id == selectedID ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.tertiary))
                                    .accessibilityHidden(true)
                                PlanTemplateRow(template: template, showsDays: false)
                            }
                        }
                        // Label colours resolve against the tint on iOS 26 — see `ExerciseEntryRows`.
                        .tint(.primary)
                        .accessibilityAddTraits(template.id == selectedID ? [.isSelected] : [])
                    }
                } header: {
                    Text("Program")
                } footer: {
                    Text("Every exercise, set and rep target can be changed later in Plans.")
                }

                Section("Weights") {
                    Picker("Unit", selection: $unit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectedID)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { dismiss() }
                        .accessibilityHint("Starts without a program. You can add one in Plans.")
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    selected.install(in: context, start: true)
                    dismiss()
                } label: {
                    Text("Start \(selected.name)")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
            }
        }
    }
}

#Preview {
    WelcomeView()
        .modelContainer(SampleData.container)
}
