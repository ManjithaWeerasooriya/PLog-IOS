//
//  BodyWeightLog.swift
//  PLog
//
//  Recording and reading body weight over time. One reading per day; the newest reading is
//  mirrored into `UserProfile.weightKg`, which the dashboard and backups already read.
//

import Foundation
import SwiftData

@MainActor
enum BodyWeightLog {
    /// A reading as plain values, for charts and figures.
    struct Reading: Identifiable, Equatable {
        let date: Date
        let weight: Double
        var id: Date { date }
    }

    /// Records `weight` for `date`'s day — replacing that day's reading if there is one —
    /// and keeps the profile on the latest reading.
    @discardableResult
    static func record(
        _ weight: Double,
        on date: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> BodyWeightEntry {
        let all = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        let sameDay = all.filter { calendar.isDate($0.date, inSameDayAs: date) }
        let entry: BodyWeightEntry
        if let existing = sameDay.first {
            existing.weight = weight
            existing.date = date
            // Older builds or an import could leave two readings on a day; keep one.
            for extra in sameDay.dropFirst() { context.delete(extra) }
            entry = existing
        } else {
            entry = BodyWeightEntry(date: date, weight: weight)
            context.insert(entry)
        }
        syncProfile(in: context)
        context.saveLogged()
        return entry
    }

    static func delete(_ entry: BodyWeightEntry, in context: ModelContext) {
        context.delete(entry)
        syncProfile(in: context, excluding: entry)
        context.saveLogged()
    }

    /// The profile's weight follows the newest reading. With no readings left it's kept as it
    /// was: a weight set before the log existed shouldn't vanish.
    private static func syncProfile(in context: ModelContext, excluding removed: BodyWeightEntry? = nil) {
        let all = (try? context.fetch(FetchDescriptor<BodyWeightEntry>())) ?? []
        // Includes unsaved inserts; a just-deleted entry can still be fetched until the save.
        guard let latest = all.filter({ $0 !== removed }).max(by: { $0.date < $1.date }) else { return }
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        profile?.weightKg = latest.weight
    }

    // MARK: - Figures

    /// Oldest first.
    static func readings(_ entries: [BodyWeightEntry]) -> [Reading] {
        entries
            .map { Reading(date: $0.date, weight: $0.weight) }
            .sorted { $0.date < $1.date }
    }

    /// The change from the reading nearest to `days` ago (at or before it, otherwise the
    /// first reading) to the latest one. `nil` with fewer than two readings.
    static func change(in readings: [Reading], over days: Int = 30, calendar: Calendar = .current) -> (amount: Double, since: Date)? {
        guard readings.count >= 2, let latest = readings.last else { return nil }
        let cutoff = calendar.date(byAdding: .day, value: -days, to: latest.date) ?? latest.date
        let earlier = readings.dropLast()
        guard let baseline = earlier.last(where: { $0.date <= cutoff }) ?? earlier.first else { return nil }
        return (((latest.weight - baseline.weight) * 10).rounded() / 10, baseline.date)
    }
}
