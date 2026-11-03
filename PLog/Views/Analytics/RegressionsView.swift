//
//  RegressionsView.swift
//  PLog
//
//  Regressing expanded, pushed from its card the way Best Lifts is. Every regressing exercise
//  (the card shows two or five), each with what's needed to decide what to do about it: the
//  two sessions compared and their estimated 1RMs, the drop, whether it's a one-off or a run
//  of sessions sliding, and a small trend so a dip can be seen against the longer climb. A
//  row opens the exercise's full history. Built from the dashboard's `DashboardStats`, so it
//  agrees with the card and costs nothing to draw; the `Exercise` destination is registered
//  in `AnalyticsView`.
//

import SwiftUI
import SwiftData
import Charts

struct RegressionsView: View {
    let stats: DashboardStats

    /// The trend shows this many recent sessions: enough to see the climb before a dip,
    /// few enough that the dip stays visible.
    private static let trendSessions = 10

    var body: some View {
        let details = stats.regressionDetails
        List {
            if details.isEmpty {
                ContentUnavailableView {
                    Label("No Regressions", systemImage: "checkmark.circle")
                } description: {
                    Text("Every exercise matched or beat its previous session.")
                }
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(details) { detail in
                        NavigationLink(value: detail.exercise) {
                            row(for: detail)
                        }
                    }
                } header: {
                    Text(summary(details))
                } footer: {
                    Text("Each session is judged on its top set's estimated one-rep max (Epley), the same comparison as Best Lifts. One dip is usually a bad day; several in a row are worth a lighter week or a change of plan.")
                }
            }
        }
        .navigationTitle("Regressing")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Row

    private func row(for detail: WorkoutStats.RegressionDetail) -> some View {
        let comparison = detail.comparison
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(detail.exercise.name)
                    .font(.headline)
                Spacer(minLength: 8)
                TrendBadge(trend: .regressed, text: "\(WeightFormatter.string(rounded(comparison.change))) kg")
            }

            HStack(spacing: 8) {
                CategoryChip(category: detail.exercise.category)
                Text(streakLabel(detail.consecutiveDips))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(detail.consecutiveDips >= 2 ? Color.orange : .secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                sessionRow("Latest", set: comparison.latest, date: comparison.latestDate)
                sessionRow("Before", set: comparison.previous, date: detail.previousDate)
            }

            ExerciseHistoryChart(
                points: Array(detail.points.suffix(Self.trendSessions)),
                metric: .oneRepMax,
                color: detail.exercise.category.color,
                height: 72
            )
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .accessibilityHidden(true)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    /// "Latest   62.5 × 6   28 Oct   e1RM 75 kg"
    private func sessionRow(_ title: String, set: SetSnapshot, date: Date?) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text("\(WeightFormatter.string(set.weight)) kg × \(set.reps)")
                .monospacedDigit()
            Text(date?.shortDateLabel ?? "")
                .foregroundStyle(.secondary)
            Text("e1RM \(WeightFormatter.string(rounded(set.estimatedOneRepMax))) kg")
                .monospacedDigit()
                .gridColumnAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .font(.subheadline)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    // MARK: - Text

    private func streakLabel(_ dips: Int) -> String {
        dips >= 2 ? "Down \(dips) sessions in a row" : "First dip"
    }

    /// "3 exercises dipped since their previous session"
    private func summary(_ details: [WorkoutStats.RegressionDetail]) -> String {
        let count = details.count
        return "\(count) \(count == 1 ? "exercise" : "exercises") dipped since the session before"
    }

    /// To one decimal, as the card shows it.
    private func rounded(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }
}

#Preview {
    NavigationStack {
        RegressionsView(stats: DashboardStats(data: SampleData.dashboardData))
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseHistoryView(exercise: exercise)
            }
    }
    .modelContainer(SampleData.container)
}
