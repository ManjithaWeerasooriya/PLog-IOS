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
    ///
    /// Two cases estimated 1RM can't judge, because it's zero whenever the weight is:
    /// - **Bodyweight sets** (0 on both sides — pull-ups, planks) are compared on reps.
    /// - **A set that hasn't been filled in** (no reps, or still 0 where last time had a
    ///   load) has no trend. A plan day is stamped before it's lifted, and painting those
    ///   sets red taught people to ignore red.
    static func trend(current: SetSnapshot, previous: SetSnapshot?) -> ProgressTrend {
        guard let previous, previous.reps > 0, current.reps > 0 else { return .none }

        if previous.weight <= 0 {
            // Last time was bodyweight: more reps, or any added load, is progress.
            if current.weight > 0 { return .improved }
            if current.reps > previous.reps { return .improved }
            return current.reps < previous.reps ? .regressed : .matched
        }
        guard current.weight > 0 else { return .none }

        let currentE1RM = current.estimatedOneRepMax
        let previousE1RM = previous.estimatedOneRepMax
        if currentE1RM > previousE1RM + tolerance { return .improved }
        if currentE1RM < previousE1RM - tolerance { return .regressed }
        return .matched
    }

    /// Small tolerance so floating point noise doesn't read as a change.
    private static let tolerance = 0.01

    /// The smallest steps that would beat `previous`: one more rep at the same weight, and
    /// the next weight up at the fewest reps that still comes out ahead on estimated 1RM
    /// (60 × 8 is beaten by 60 × 9 or by 62.5 × 7). Shown beside a set so "progress" is a
    /// concrete number rather than a colour after the fact. A bodyweight set only has the
    /// rep target; empty when there's nothing to beat.
    static func targets(toBeat previous: SetSnapshot, step: Double) -> [SetSnapshot] {
        guard previous.reps > 0 else { return [] }
        var targets = [SetSnapshot(weight: previous.weight, reps: previous.reps + 1)]
        guard previous.weight > 0, step > 0 else { return targets }

        let heavier = previous.weight + step
        // Fewest whole reps whose e1RM clears the previous one.
        let exact = 30 * (previous.estimatedOneRepMax / heavier - 1)
        var reps = max(1, Int(exact.rounded(.down)) + 1)
        while SetSnapshot(weight: heavier, reps: reps).estimatedOneRepMax <= previous.estimatedOneRepMax + tolerance {
            reps += 1
        }
        targets.append(SetSnapshot(weight: heavier, reps: reps))
        return targets
    }

    /// A short inline hint shown while logging, e.g. "Last time: 60 kg × 8".
    static func lastTimeLabel(for snapshot: SetSnapshot?, unit: WeightUnit) -> String? {
        guard let snapshot, snapshot.reps > 0 else { return nil }
        return "Last time: \(setLabel(snapshot, unit: unit))"
    }

    /// "60 kg × 8", or "12 reps" for a bodyweight set.
    static func setLabel(_ snapshot: SetSnapshot, unit: WeightUnit) -> String {
        snapshot.weight > 0 ? "\(unit.string(snapshot.weight)) × \(snapshot.reps)" : repsLabel(snapshot.reps)
    }

    /// "60 × 9" — a target beside a label that already names the unit.
    static func shortSetLabel(_ snapshot: SetSnapshot) -> String {
        snapshot.weight > 0 ? "\(WeightFormatter.string(snapshot.weight)) × \(snapshot.reps)" : repsLabel(snapshot.reps)
    }

    private static func repsLabel(_ reps: Int) -> String {
        "\(reps) \(reps == 1 ? "rep" : "reps")"
    }
}
