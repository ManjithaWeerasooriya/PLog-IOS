//
//  AddExerciseView.swift
//  PLog
//
//  A form for adding a new exercise to the master library, or editing an existing one.
//

import SwiftUI
import SwiftData

struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// The exercise being edited. `nil` means this is the "New Exercise" flow.
    let exercise: Exercise?
    /// Optional callback fired with the newly created (or edited) exercise (used by the
    /// picker flow to select whatever the user just made).
    let onCreate: ((Exercise) -> Void)?

    @State private var name: String
    @State private var primary: Set<MuscleGroup>
    @State private var secondary: Set<MuscleGroup>
    @State private var notes: String
    @State private var confirmingDiscard = false

    private var isEditing: Bool { exercise != nil }

    /// Compares the draft fields against the exercise as it stood when this sheet opened
    /// (or, for a new exercise, against a blank draft) to decide whether Cancel needs to
    /// confirm before discarding.
    private var hasChanges: Bool {
        guard let exercise else {
            return !trimmedName.isEmpty || primary != [.chest] || !secondary.isEmpty || !notes.isEmpty
        }
        return name != exercise.name
            || primary != Set(exercise.primaryMuscles)
            || secondary != Set(exercise.secondaryMuscles)
            || notes != exercise.notes
    }

    /// Seeds the `@State` once, here, rather than in `.onAppear` — `.onAppear` re-fires when
    /// a pushed Primary/Secondary screen is popped back to this one (the view "reappears"),
    /// which was stomping the just-picked groups back to the exercise's original stored
    /// values before the user ever saw the change stick.
    init(exercise: Exercise? = nil, prefilledName: String = "", onCreate: ((Exercise) -> Void)? = nil) {
        self.exercise = exercise
        self.onCreate = onCreate
        _name = State(initialValue: exercise?.name ?? prefilledName)
        _primary = State(initialValue: Set(exercise?.primaryMuscles ?? [.chest]))
        _secondary = State(initialValue: Set(exercise?.secondaryMuscles ?? []))
        _notes = State(initialValue: exercise?.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Exercise") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    NavigationLink {
                        MuscleGroupSelectionView(role: .primary, selection: $primary, taken: secondary)
                    } label: {
                        LabeledContent("Primary", value: primary.isEmpty ? "None" : MuscleGroup.names(primary))
                    }
                    NavigationLink {
                        MuscleGroupSelectionView(role: .secondary, selection: $secondary, taken: primary)
                    } label: {
                        LabeledContent("Secondary", value: secondary.isEmpty ? "None" : MuscleGroup.names(secondary))
                    }
                } header: {
                    Text("Muscle Groups")
                } footer: {
                    if primary.isEmpty {
                        Text("Choose at least one primary muscle group.")
                    }
                }

                Section("Notes") {
                    TextField("Form cues, machine settings, etc.", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(baseTitle)
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
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty || primary.isEmpty)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .alert("Discard Changes?", isPresented: $confirmingDiscard) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text(isEditing ? "Your edits to this exercise will be lost." : "This exercise won't be created.")
            }
        }
    }

    private var baseTitle: String {
        isEditing ? "Edit Exercise" : "New Exercise"
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func save() {
        if let exercise {
            exercise.name = trimmedName
            exercise.setMuscles(primary: primary, secondary: secondary)
            exercise.notes = notes
            try? context.save()
            onCreate?(exercise)
        } else {
            let created = Exercise(name: trimmedName, notes: notes)
            created.setMuscles(primary: primary, secondary: secondary)
            context.insert(created)
            try? context.save()
            onCreate?(created)
        }
        dismiss()
    }
}

#Preview("New Exercise") {
    AddExerciseView()
        .modelContainer(SampleData.container)
}

#Preview("Edit Exercise") {
    AddExerciseView(exercise: SampleData.benchPress)
        .modelContainer(SampleData.container)
}
