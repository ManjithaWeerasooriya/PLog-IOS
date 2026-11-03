//
//  ExerciseHistoryView.swift
//  PLog
//
//  Visualizes progressive overload for one exercise as a Swift Charts line over time.
//  A segmented picker switches between top weight, top-set reps, total volume, and est. 1RM.
//

import SwiftUI
import SwiftData

struct ExerciseHistoryView: View {
    @State private var viewModel: ExerciseHistoryViewModel
    @State private var showingEdit = false

    init(exercise: Exercise) {
        _viewModel = State(initialValue: ExerciseHistoryViewModel(exercise: exercise))
    }

    var body: some View {
        // Read once: each read walks the exercise's whole history.
        let points = viewModel.points
        return List {
            Section {
                Picker("Metric", selection: $viewModel.selectedMetric) {
                    ForEach(ExerciseHistoryViewModel.Metric.allCases) { metric in
                        Text(metric.shortLabel).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                chartSection(points)
            }

            if !points.isEmpty {
                Section("Sessions") {
                    ForEach(points.reversed()) { point in
                        HStack {
                            Text(point.date.mediumDayLabel)
                            Spacer()
                            Text(sessionLabel(for: point))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(viewModel.exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEdit = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddExerciseView(exercise: viewModel.exercise)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private func chartSection(_ points: [ExerciseHistoryPoint]) -> some View {
        if !points.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(viewModel.selectedMetric.rawValue)
                        .font(.headline)
                    TrendBadge(trend: viewModel.selectedMetric.overallTrend(of: points))
                    Spacer()
                }

                ExerciseHistoryChart(
                    points: points,
                    metric: viewModel.selectedMetric,
                    color: viewModel.exercise.category.color
                )
            }
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
        } else {
            ExerciseHistoryEmptyView()
                .listRowSeparator(.hidden)
        }
    }

    private func sessionLabel(for point: ExerciseHistoryPoint) -> String {
        let value = viewModel.value(for: point)
        let unit = viewModel.selectedMetric.unit
        switch viewModel.selectedMetric {
        case .reps:
            return "\(Int(value)) \(unit)"
        default:
            return "\(WeightFormatter.string(value)) \(unit)"
        }
    }
}

#Preview {
    NavigationStack {
        ExerciseHistoryView(exercise: SampleData.benchPress)
    }
    .modelContainer(SampleData.container)
}
