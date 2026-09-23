//
//  SessionDetailsSheet.swift
//  PLog
//
//  Edits a session's name, date and notes — the metadata that used to sit above the
//  exercises. A local-draft modal editor (Cancel / Done, confirm before discarding), same
//  lane as `AddExerciseView`; the model isn't touched until Done.
//

import SwiftUI
import SwiftData

struct SessionDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let day: WorkoutDay

    /// Every other session, to block moving this one onto a day that's already taken —
    /// only one workout can be logged per day.
    @Query private var allDays: [WorkoutDay]

    @State private var name: String
    @State private var date: Date
    @State private var notes: String
    @State private var confirmingDiscard = false

    /// Seeded once here, not in `.onAppear` — see the `AddExerciseView` note in AGENT.md.
    init(day: WorkoutDay) {
        self.day = day
        _name = State(initialValue: day.name)
        _date = State(initialValue: day.date)
        _notes = State(initialValue: day.notes)
    }

    private var hasChanges: Bool {
        name != day.name || date != day.date || notes != day.notes
    }

    /// Whether another session already exists on the picked date — only one workout can be
    /// logged per day.
    private var dateIsTaken: Bool {
        allDays.contains { $0 !== day && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Workout name", text: $name)
                        .textInputAutocapitalization(.words)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    if let planDay = day.planDay {
                        LabeledContent("Plan Day") {
                            Text(planDayLabel(planDay))
                                .foregroundStyle(.secondary)
                        }
                    }
                } footer: {
                    if dateIsTaken {
                        Text("A workout is already logged on this date. Only one workout can be logged per day.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Notes") {
                    TextField("How did it go?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            confirmingDiscard = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: save)
                        .fontWeight(.semibold)
                        .disabled(dateIsTaken)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("Discard Changes?", isPresented: $confirmingDiscard) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Your edits to this workout will be lost.")
            }
        }
    }

    /// e.g. "Push Day · Push / Pull / Legs".
    private func planDayLabel(_ planDay: PlanDay) -> String {
        let dayName = planDay.name.isEmpty ? "Day" : planDay.name
        guard let planName = planDay.plan?.name, !planName.isEmpty else { return dayName }
        return "\(dayName) · \(planName)"
    }

    private func save() {
        day.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        day.date = date
        day.notes = notes
        try? context.save()
        dismiss()
    }
}

#Preview {
    SessionDetailsSheet(day: SampleData.recentDay)
        .modelContainer(SampleData.container)
}
