//
//  WorkoutPlan.swift
//  PLog
//
//  A multi-week training program made of named day templates (Push Day, Pull Day, …).
//  The user starts a plan, logs sessions against it for a few months, then ends it.
//

import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    /// Display name, e.g. "PPL Spring 2026".
    var name: String

    var notes: String

    var createdAt: Date

    /// When the user tapped "Start". `nil` until the plan is started.
    var startedAt: Date?

    /// When the user tapped "End". `nil` while the plan is active or not yet started.
    var endedAt: Date?

    /// The day templates that make up this plan.
    ///
    /// Cascade delete: removing a plan removes its day templates (and their exercise
    /// templates). Logged `WorkoutDay` records are NOT touched — see `PlanDay.loggedDays`.
    @Relationship(deleteRule: .cascade, inverse: \PlanDay.plan)
    var days: [PlanDay] = []

    init(
        name: String = "",
        notes: String = "",
        createdAt: Date = .now,
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Day templates in the user's chosen rotation order.
    var orderedDays: [PlanDay] {
        days.sorted { $0.order < $1.order }
    }

    /// Training days a week: every day's `timesPerWeek` added up.
    var daysPerWeek: Int {
        days.reduce(0) { $0 + $1.timesPerWeek }
    }

    var status: PlanStatus {
        guard startedAt != nil else { return .notStarted }
        return endedAt == nil ? .active : .ended
    }

    var isActive: Bool { status == .active }
}
