//
//  WorkoutDayRow.swift
//  PLog
//
//  A single row summarizing one logged session: date and name, then what was done. Two
//  lines — a row exists to be recognized and tapped, and the exercise list is what makes a
//  session recognizable. The date leads (it's what distinguishes same-named sessions in the
//  list), with the day name trailing as a secondary label.
//

import SwiftUI
import SwiftData

struct WorkoutDayRow: View {
    let day: WorkoutDay

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date and name share a line until accessibility sizes, where they'd wrap into
            // a column of single words; then the name drops under the date.
            if typeSize.isAccessibilitySize {
                dateLabel
                nameLabel
            } else {
                HStack(alignment: .firstTextBaseline) {
                    dateLabel
                    Spacer()
                    nameLabel
                }
            }
            Text(summary)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var dateLabel: some View {
        Text(day.date.mediumDayLabel)
            .font(.headline)
    }

    private var nameLabel: some View {
        Text(day.name.isEmpty ? "Workout" : day.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    /// e.g. "Bench Press · Overhead Press · Lateral Raise".
    private var summary: String {
        let names = day.orderedEntries.compactMap { $0.exercise?.name }
        return names.isEmpty ? "No exercises" : names.joined(separator: " · ")
    }
}

#Preview {
    List {
        WorkoutDayRow(day: SampleData.recentDay)
    }
    .modelContainer(SampleData.container)
}
