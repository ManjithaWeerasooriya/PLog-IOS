//
//  ExerciseProgressWidget.swift
//  PLog
//
//  One exercise's estimated 1RM over time, drawn with the same chart as its history screen.
//  The card pushes that screen. With no exercise (it was deleted, or there was none to
//  pick when the widget was added) the card asks for one instead of vanishing.
//

import SwiftUI
import SwiftData

struct ExerciseProgressWidget: View {
    let exercise: Exercise?
    var size: DashboardWidgetSize = .wide
    var onChooseExercise: () -> Void

    var body: some View {
        if let exercise {
            NavigationLink(value: exercise) {
                AnalyticsCard {
                    content(for: exercise)
                }
            }
            .buttonStyle(.plain)
        } else {
            AnalyticsCard {
                VStack(alignment: .leading, spacing: 12) {
                    AnalyticsCardTitle(title: DashboardWidgetKind.exerciseProgress.title)
                    ContentUnavailableView {
                        Label("No Exercise", systemImage: "dumbbell")
                    } description: {
                        if size == .large {
                            Text("Choose the exercise this widget tracks.")
                        }
                    } actions: {
                        Button("Choose Exercise", action: onChooseExercise)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func content(for exercise: Exercise) -> some View {
        let points = WorkoutHistory.historyPoints(for: exercise)
        let metric = ExerciseHistoryViewModel.Metric.oneRepMax
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                AnalyticsCardTitle(title: exercise.name, subtitle: subtitle(sessions: points.count))
                Spacer()
                // Wide: the latest figure sits in the header to leave the chart room.
                if size == .wide, let latest = points.last {
                    latestStat(latest, metric: metric)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            if let latest = points.last {
                if size == .large {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            latestStat(latest, metric: metric)
                            TrendBadge(trend: metric.overallTrend(of: points))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            latestStat(latest, metric: metric)
                            TrendBadge(trend: metric.overallTrend(of: points))
                        }
                    }
                }
                ExerciseHistoryChart(
                    points: points,
                    metric: metric,
                    color: exercise.category.color,
                    height: nil
                )
            } else if size == .large {
                ExerciseHistoryEmptyView()
            } else {
                ContentUnavailableView("No History Yet", systemImage: "chart.xyaxis.line")
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func latestStat(_ point: ExerciseHistoryPoint, metric: ExerciseHistoryViewModel.Metric) -> some View {
        BigStat(value: WeightFormatter.string(metric.value(of: point)), unit: "kg", style: .title2)
    }

    private func subtitle(sessions: Int) -> String {
        "Est. 1RM · \(sessions) session\(sessions == 1 ? "" : "s")"
    }
}

#Preview {
    NavigationStack {
        ScrollView {
            VStack(spacing: 16) {
                ExerciseProgressWidget(exercise: SampleData.benchPress, onChooseExercise: {})
                ExerciseProgressWidget(exercise: nil, onChooseExercise: {})
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }
    .modelContainer(SampleData.container)
}
