//
//  ExerciseHistoryViewModel.swift
//  PLog
//
//  Prepares an exercise's logged history for the Swift Charts trend screen.
//

import Foundation

@MainActor
@Observable
final class ExerciseHistoryViewModel {
    let exercise: Exercise

    /// The metric currently plotted.
    enum Metric: String, CaseIterable, Identifiable {
        case weight = "Top Weight"
        case reps = "Top Set Reps"
        case volume = "Total Volume"
        case oneRepMax = "Est. 1RM"

        var id: String { rawValue }

        /// Fits four segments across a phone; `rawValue` is the full chart title.
        var shortLabel: String {
            switch self {
            case .weight: return "Weight"
            case .reps: return "Reps"
            case .volume: return "Volume"
            case .oneRepMax: return "1RM"
            }
        }

        var unit: String {
            switch self {
            case .weight, .volume, .oneRepMax: return "kg"
            case .reps: return "reps"
            }
        }

        /// This metric's value at one logged session.
        func value(of point: ExerciseHistoryPoint) -> Double {
            switch self {
            case .weight: return point.topWeight
            case .reps: return Double(point.topSetReps)
            case .volume: return point.totalVolume
            case .oneRepMax: return point.estimatedOneRepMax
            }
        }

        /// First logged value vs last; `.none` with fewer than two sessions.
        func overallTrend(of points: [ExerciseHistoryPoint]) -> ProgressTrend {
            guard let first = points.first, let last = points.last, points.count >= 2 else {
                return .none
            }
            let start = value(of: first)
            let end = value(of: last)
            if end > start { return .improved }
            if end < start { return .regressed }
            return .matched
        }
    }

    var selectedMetric: Metric = .weight

    /// Which sessions are shown when the exercise has been done both ways. Starts on the way
    /// it was done most recently.
    var handMode: HandMode

    init(exercise: Exercise) {
        self.exercise = exercise
        self.handMode = WorkoutHistory.historyPoints(for: exercise).last?.handMode ?? exercise.defaultHandMode
    }

    /// The hand modes the exercise has been logged with; the filter shows only with both.
    var loggedHandModes: [HandMode] {
        WorkoutHistory.loggedHandModes(for: exercise)
    }

    /// Logged sessions done with `handMode`, oldest → newest — one-hand and two-hand weights
    /// aren't comparable, so they never share a line. With only one mode logged, all of them.
    var points: [ExerciseHistoryPoint] {
        loggedHandModes.count > 1
            ? WorkoutHistory.historyPoints(for: exercise, handMode: handMode)
            : WorkoutHistory.historyPoints(for: exercise)
    }

    var hasEnoughDataForChart: Bool { points.count >= 1 }

    /// The value for the currently selected metric at a given point.
    func value(for point: ExerciseHistoryPoint) -> Double {
        selectedMetric.value(of: point)
    }

    /// Overall trend across the whole history (first vs last logged value).
    var overallTrend: ProgressTrend {
        selectedMetric.overallTrend(of: points)
    }
}
