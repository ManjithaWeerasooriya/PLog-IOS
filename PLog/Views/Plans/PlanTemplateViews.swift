//
//  PlanTemplateViews.swift
//  PLog
//
//  The ready-made programs (`PlanTemplate`) as rows, and the sheet the Plans tab opens to
//  add one. The welcome sheet lists the same rows.
//

import SwiftUI
import SwiftData

/// One program: its name, how many days a week it takes, who it suits and its days.
struct PlanTemplateRow: View {
    let template: PlanTemplate
    /// The day names under the summary. The welcome sheet leaves them out to stay short.
    var showsDays = true

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Name and frequency share a line until accessibility sizes, like a session row.
            if typeSize.isAccessibilitySize {
                name
                frequency
            } else {
                HStack(alignment: .firstTextBaseline) {
                    name
                    Spacer(minLength: 8)
                    frequency
                }
            }
            Text(template.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if showsDays {
                Text(template.dayNames)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var name: some View {
        Text(template.name)
            .font(.headline)
            .foregroundStyle(.primary)
    }

    private var frequency: some View {
        Text(template.frequencyLabel)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

/// The programs as a sheet: tap one to add it as a plan. From the Plans tab it's added
/// without being started — the plan screen it opens has the Start button, like any other
/// plan. From Train's "No plan yet" card it's started straight away (`startsPlan`), since
/// the point there is to have something to log today.
struct PlanTemplateGallery: View {
    var startsPlan = false
    /// Handed the new plan after the sheet has added it, so the caller can open it.
    var onAdd: (WorkoutPlan) -> Void = { _ in }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(PlanTemplate.all) { template in
                        Button {
                            let plan = template.install(in: context, start: startsPlan)
                            dismiss()
                            onAdd(plan)
                        } label: {
                            HStack(spacing: 12) {
                                PlanTemplateRow(template: template)
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                        }
                        // Label colours resolve against the tint on iOS 26 — see `ExerciseEntryRows`.
                        .tint(.primary)
                        .accessibilityHint(startsPlan ? "Starts this program" : "Adds this program to your plans")
                    }
                } footer: {
                    Text("Each program reaches 10 or more weekly sets for the main muscle groups. "
                         + (startsPlan
                            ? "It becomes your active plan, and you can edit it in Plans."
                            : "It's added as a plan you can edit, and it starts when you start it."))
                }
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    PlanTemplateGallery(onAdd: { _ in })
        .modelContainer(SampleData.container)
}
