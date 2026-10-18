//
//  ExerciseHistoryChart.swift
//  PLog
//
//  One exercise's logged sessions as a line over time, for one metric. Shared by the
//  exercise history screen, the Exercise Progress widget and the expanded Best Lifts screen,
//  so an exercise's progress looks the same wherever it's drawn.
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryChart: View {
    let points: [ExerciseHistoryPoint]
    let metric: ExerciseHistoryViewModel.Metric
    let color: Color
    /// `nil` fills whatever height the container gives it (the dashboard grid).
    var height: CGFloat? = 220

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.rawValue, metric.value(of: point))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(color)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.rawValue, metric.value(of: point))
            )
            .foregroundStyle(color)
        }
        .frame(minHeight: height ?? 60, maxHeight: height ?? .infinity)
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .chartYScale(domain: .automatic(includesZero: false))
    }
}

/// What every exercise chart shows before the exercise has been logged.
struct ExerciseHistoryEmptyView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No History Yet", systemImage: "chart.xyaxis.line")
        } description: {
            Text("Log this exercise a few times to see your progress trend.")
        }
    }
}

#Preview {
    ExerciseHistoryChart(
        points: WorkoutHistory.historyPoints(for: SampleData.benchPress),
        metric: .oneRepMax,
        color: .blue
    )
    .padding()
    .modelContainer(SampleData.container)
}
