//
//  MuscleGroupSelectionView.swift
//  PLog
//
//  Picks an exercise's primary or secondary muscle groups — one role per screen, pushed from
//  `AddExerciseView` and editing that form's draft through a binding (the form saves on Save).
//

import SwiftUI

/// The part a muscle group plays in an exercise.
enum MuscleRole {
    case primary, secondary

    var title: String {
        switch self {
        case .primary: return "Primary"
        case .secondary: return "Secondary"
        }
    }

    var other: MuscleRole {
        self == .primary ? .secondary : .primary
    }
}

/// A checklist of every group for one role. Groups already in the other role are shown
/// greyed out with that role's name, so this screen never changes the other list.
struct MuscleGroupSelectionView: View {
    let role: MuscleRole
    @Binding var selection: Set<MuscleGroup>
    /// The other role's groups — not selectable here.
    let taken: Set<MuscleGroup>

    var body: some View {
        List {
            Section {
                ForEach(MuscleGroup.allCases) { group in
                    row(for: group)
                }
            } footer: {
                Text(footer)
            }
        }
        .navigationTitle("\(role.title) Muscles")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(for group: MuscleGroup) -> some View {
        let isTaken = taken.contains(group)
        let isSelected = selection.contains(group)
        return Button {
            if isSelected {
                selection.remove(group)
            } else {
                selection.insert(group)
            }
        } label: {
            HStack {
                Label {
                    Text(group.displayName)
                } icon: {
                    MuscleGroupIcon(group)
                        .opacity(isTaken ? 0.5 : 1)
                }
                .foregroundStyle(isTaken ? .secondary : .primary)
                Spacer()
                if isTaken {
                    Text(role.other.title)
                        .foregroundStyle(.secondary)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .contentShape(Rectangle())
        }
        // Names in label colour, not the button tint.
        .tint(.primary)
        .disabled(isTaken)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var footer: String {
        switch role {
        case .primary:
            return "The exercise is listed under each primary group, and every set counts fully toward it."
        case .secondary:
            return "Secondary groups aren't listed in the library. Each set counts as half a set toward them."
        }
    }
}

extension MuscleGroup {
    /// Names groups in `allCases` order, e.g. "Chest, Triceps".
    static func names(_ groups: some Collection<MuscleGroup>) -> String {
        allCases.filter(groups.contains).map(\.displayName).joined(separator: ", ")
    }
}

#Preview {
    @Previewable @State var secondary: Set<MuscleGroup> = [.triceps, .shoulders]
    NavigationStack {
        MuscleGroupSelectionView(role: .secondary, selection: $secondary, taken: [.chest])
    }
}
