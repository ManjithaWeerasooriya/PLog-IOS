//
//  PlanVolume.swift
//  PLog
//
//  Planned working sets per muscle group per week for a `WorkoutPlan`, counted the way the
//  Muscle Groups widget counts logged sets (`WorkoutStats.muscleGroupSplit`): a set counts
//  in full for each of its exercise's primary groups and as `secondarySetWeight` for each
//  secondary one, judged against `HypertrophyTarget`. Each day counts as many times as its
//  `timesPerWeek` (set on the day's screen; once by default).
//

import Foundation
import SwiftData

enum PlanVolume {
    /// One slot's share of a muscle group's weekly sets.
    struct Contribution: Identifiable {
        let slot: PlanExercise
        let dayName: String
        /// How many times a week the slot's day runs.
        let timesPerWeek: Int
        let isPrimary: Bool
        let weeklySets: Double
        var id: PersistentIdentifier { slot.persistentModelID }
    }

    struct GroupVolume: Identifiable {
        let group: MuscleGroup
        let weeklySets: Double
        /// Primary contributions first, then by weekly sets.
        let contributions: [Contribution]
        var id: MuscleGroup { group }

        /// `nil` for Cardio, Full Body and Other, which the target doesn't apply to.
        var status: HypertrophyTarget.Status? {
            HypertrophyTarget.applies(to: group) ? HypertrophyTarget.status(weeklySets: weeklySets) : nil
        }
    }

    struct Summary {
        /// Sets actually planned a week (not weighted), the section's headline figure.
        let weeklySets: Double
        /// Every target muscle group (untrained ones at 0) plus any other trained group,
        /// largest first.
        let groups: [GroupVolume]

        var isEmpty: Bool { weeklySets == 0 }
        var onTargetCount: Int { groups.filter { $0.status == .met }.count }
        var belowCount: Int { groups.filter { $0.status == .below }.count }
        var highCount: Int { groups.filter { $0.status == .high }.count }
    }

    static func summary(for plan: WorkoutPlan) -> Summary {
        var totals: [MuscleGroup: Double] = [:]
        var contributions: [MuscleGroup: [Contribution]] = [:]
        var weeklySets = 0.0

        for day in plan.days {
            let times = day.timesPerWeek
            for slot in day.exercises {
                guard let exercise = slot.exercise else { continue }
                let perWeek = Double(slot.targetSets * times)
                weeklySets += perWeek
                for group in exercise.primaryMuscles {
                    totals[group, default: 0] += perWeek
                    contributions[group, default: []].append(
                        Contribution(slot: slot, dayName: day.name, timesPerWeek: times, isPrimary: true, weeklySets: perWeek)
                    )
                }
                let secondary = perWeek * WorkoutStats.secondarySetWeight
                for group in exercise.secondaryMuscles {
                    totals[group, default: 0] += secondary
                    contributions[group, default: []].append(
                        Contribution(slot: slot, dayName: day.name, timesPerWeek: times, isPrimary: false, weeklySets: secondary)
                    )
                }
            }
        }

        let groups = MuscleGroup.allCases
            .filter { HypertrophyTarget.applies(to: $0) || (totals[$0] ?? 0) > 0 }
            .map { group in
                GroupVolume(
                    group: group,
                    weeklySets: totals[group] ?? 0,
                    contributions: (contributions[group] ?? []).sorted {
                        $0.isPrimary != $1.isPrimary ? $0.isPrimary : $0.weeklySets > $1.weeklySets
                    }
                )
            }
            // Stable for ties: `allCases` order, so rows don't swap places while stepping.
            .enumerated()
            .sorted { $0.element.weeklySets != $1.element.weeklySets ? $0.element.weeklySets > $1.element.weeklySets : $0.offset < $1.offset }
            .map(\.element)

        return Summary(weeklySets: weeklySets, groups: groups)
    }

    /// For a group below target: the primary slot with the most sets a week, and how many more
    /// sets per session on it reach the minimum (its day may run more than once a week). `nil`
    /// when nothing trains the group as a primary.
    static func suggestion(for volume: GroupVolume) -> (slot: PlanExercise, extraSets: Int)? {
        guard volume.status == .below,
              let best = volume.contributions.first(where: \.isPrimary) else { return nil }
        let deficit = HypertrophyTarget.minimumWeeklySets - volume.weeklySets
        return (best.slot, max(1, Int((deficit / Double(best.timesPerWeek)).rounded(.up))))
    }

    /// "14" or "9.5": half-sets from secondary muscles can leave a .5; dropped when zero.
    static func setString(_ sets: Double) -> String {
        let rounded = (sets * 10).rounded() / 10
        return rounded == rounded.rounded() ? "\(Int(rounded))" : String(format: "%.1f", rounded)
    }
}
