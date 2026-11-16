//
//  EffortTracking.swift
//  PLog
//
//  Reps in reserve (RIR): how many more reps a set had in it. Sets taken close to failure
//  are the ones that drive growth, so lifters who program by effort want it on record.
//  It's optional — off until switched on in Settings — because most people don't, and a
//  third control on every set is clutter for them.
//

import Foundation

enum EffortTracking {
    /// `@AppStorage` key for the Settings toggle.
    static let storageKey = "tracksRepsInReserve"

    /// 0 is to failure; 4 stands for "four or more", past which the estimate isn't reliable.
    static let choices = [0, 1, 2, 3, 4]

    static func label(_ repsInReserve: Int) -> String {
        repsInReserve >= 4 ? "4+" : "\(repsInReserve)"
    }
}

extension SetEntry {
    /// Reps in reserve, 0…4 (4 meaning four or more), or `nil` when not recorded. Stored in
    /// the long-standing `rpe` field as 10 − RIR, so backups need no new key.
    var repsInReserve: Int? {
        get { rpe.map { min(max(Int((10 - $0).rounded()), 0), 4) } }
        set { rpe = newValue.map { 10 - Double(min(max($0, 0), 4)) } }
    }
}
