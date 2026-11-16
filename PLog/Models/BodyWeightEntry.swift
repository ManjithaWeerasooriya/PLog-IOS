//
//  BodyWeightEntry.swift
//  PLog
//
//  One body-weight reading on one day. The log is what turns the single profile number into
//  a trend, which is how a bulk or a cut is actually judged. `UserProfile.weightKg` stays
//  the latest reading (see `BodyWeightLog`), so everything that read it still works.
//

import Foundation
import SwiftData

@Model
final class BodyWeightEntry {
    /// The day of the reading (any time that day; there is one entry per day).
    var date: Date

    /// In the user's weight unit, like every other stored weight.
    var weight: Double

    init(date: Date = .now, weight: Double) {
        self.date = date
        self.weight = weight
    }
}
