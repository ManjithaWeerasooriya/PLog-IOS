//
//  ProgressiveOverload.swift
//  PLog
//
//  The core "should I go heavier?" logic. Compares a set against the equivalent set
//  from the previous session and classifies it as an improvement, regression, or match.
//

import SwiftUI

/// A lightweight, model-free snapshot of a set's numbers.
///
/// Used for prefilling the entry form and for comparisons, so we don't have to pass
/// live SwiftData objects around the UI.
struct SetSnapshot: Equatable {
    var weight: Double
    var reps: Int

    /// Estimated one-rep max via the Epley formula. Lets us compare sets even when the
    /// user trades weight for reps (e.g. 60×8 vs 65×6) using a single number.
    var estimatedOneRepMax: Double {
        guard reps > 0 else { return 0 }
        return weight * (1.0 + Double(reps) / 30.0)
    }
}

/// The direction of change versus the previous session.
enum ProgressTrend {
    case improved
    case regressed
    case matched
    case none

    var color: Color {
        switch self {
        case .improved: return .green
        case .regressed: return .red
        case .matched: return .secondary
        case .none: return .secondary
        }
    }

    var systemImage: String? {
        switch self {
        case .improved: return "arrow.up.right"
        case .regressed: return "arrow.down.right"
        case .matched: return "equal"
        case .none: return nil
        }
    }

    /// What VoiceOver reads for the badge, which is otherwise just a coloured arrow.
    var accessibilityLabel: String {
        switch self {
        case .improved: return "Improved"
        case .regressed: return "Regressed"
        case .matched: return "Same as last time"
        case .none: return ""
        }
    }
}

enum ProgressiveOverload {
    /// Classify a set relative to the previous session's comparable set.
    ///
    /// We use estimated 1RM so that increasing either weight or reps counts as progress.
    static func trend(current: SetSnapshot, previous: SetSnapshot?) -> ProgressTrend {
        guard let previous, previous.estimatedOneRepMax > 0 else { return .none }

        let currentE1RM = current.estimatedOneRepMax
        let previousE1RM = previous.estimatedOneRepMax

        // Small tolerance so floating point noise doesn't read as a change.
        let tolerance = 0.01
        if currentE1RM > previousE1RM + tolerance { return .improved }
        if currentE1RM < previousE1RM - tolerance { return .regressed }
        return .matched
    }

    /// A short inline hint shown while logging, e.g. "Last time: 60 kg × 8".
    static func lastTimeLabel(for snapshot: SetSnapshot?, unit: String = "kg") -> String? {
        guard let snapshot, snapshot.reps > 0 else { return nil }
        let weight = WeightFormatter.string(snapshot.weight)
        return "Last time: \(weight) \(unit) × \(snapshot.reps)"
    }
}
