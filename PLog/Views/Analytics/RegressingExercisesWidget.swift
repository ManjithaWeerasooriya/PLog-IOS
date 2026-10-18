//
//  RegressingExercisesWidget.swift
//  PLog
//
//  Exercises whose latest session's estimated 1RM came in under the session before, with
//  the drop. Fed by `WorkoutStats.regressingExercises`, which compares top sets exactly as
//  Best Lifts' trend arrow does, so the two never disagree about an exercise.
//

import SwiftUI
import SwiftData

struct RegressingExercisesWidget: View {
    let regressions: [WorkoutStats.SessionComparison]
    var size: DashboardWidgetSize = .wide

    var body: some View {
        // Wide fits two rows; large fits five. The rest are counted, not dropped silently.
        let limit = size == .large ? 5 : 2
        let shown = Array(regressions.prefix(limit))
        AnalyticsCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    AnalyticsCardTitle(title: "Regressing", subtitle: "Est. 1RM vs the session before")
                    Spacer()
                    if regressions.count > limit {
                        Text("+\(regressions.count - limit) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if regressions.isEmpty {
                    if size == .large {
                        ContentUnavailableView {
                            Label("No Regressions", systemImage: "checkmark.circle")
                        } description: {
                            Text("Every exercise matched or beat its previous session.")
                        }
                    } else {
                        ContentUnavailableView("No Regressions", systemImage: "checkmark.circle")
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, comparison in
                            row(for: comparison)
                            if index < shown.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private func row(for comparison: WorkoutStats.SessionComparison) -> some View {
        NavigationLink(value: comparison.exercise) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(comparison.exercise.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(setsLabel(for: comparison))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                TrendBadge(
                    trend: .regressed,
                    text: "\(WeightFormatter.string(roundedChange(comparison))) kg"
                )
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, size == .large ? 10 : 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// "62.5 × 6, was 65 × 8 · Sep 16"
    private func setsLabel(for comparison: WorkoutStats.SessionComparison) -> String {
        let latest = "\(WeightFormatter.string(comparison.latest.weight)) × \(comparison.latest.reps)"
        let previous = "\(WeightFormatter.string(comparison.previous.weight)) × \(comparison.previous.reps)"
        return "\(latest), was \(previous) · \(comparison.latestDate.shortDateLabel)"
    }

    /// To one decimal, so the badge reads "−3.3 kg" rather than "−3.3333 kg".
    private func roundedChange(_ comparison: WorkoutStats.SessionComparison) -> Double {
        (comparison.change * 10).rounded() / 10
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            RegressingExercisesWidget(regressions: [])
                .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .modelContainer(SampleData.container)
}
