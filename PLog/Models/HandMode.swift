//
//  HandMode.swift
//  PLog
//
//  Whether an exercise is done with both hands together or one hand at a time. The logged
//  weight is always the load in one hand (one dumbbell, one cable handle); one-hand reps are
//  per side. Sessions are only compared with sessions done the same way.
//

import Foundation

nonisolated enum HandMode: String, Codable, CaseIterable, Identifiable {
    case both
    case single

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .both: return "Two Hands"
        case .single: return "One Hand"
        }
    }

    /// Lower-case, for running text: "Last time, one hand: …".
    var phrase: String {
        switch self {
        case .both: return "two hands"
        case .single: return "one hand"
        }
    }

    var explanation: String {
        switch self {
        case .both: return "Both arms together, like a barbell or a bar attachment"
        case .single: return "One arm at a time; reps are per side"
        }
    }

    /// Appended to a rep count: "12 / side" for one hand, nothing for two.
    var repSuffix: String {
        self == .single ? " / side" : ""
    }

    /// A stored raw value, falling back to two hands for `nil` or anything unknown.
    init(storedValue: String?) {
        self = storedValue.flatMap(HandMode.init(rawValue:)) ?? .both
    }
}
