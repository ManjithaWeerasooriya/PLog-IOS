//
//  WeightUnit.swift
//  PLog
//
//  The unit weights are entered and shown in. It's a label and a step size, not a storage
//  format: a stored weight is simply the number the user entered, in whichever unit they
//  train in. Switching units in Settings offers to convert what's already logged.
//

import SwiftUI
import SwiftData

/// `nonisolated`: a plain value, read from default arguments and background code alike.
nonisolated enum WeightUnit: String, CaseIterable, Identifiable {
    case kg
    case lb

    /// `UserDefaults` key, shared by `PLogApp`, Settings and `current`.
    static let storageKey = "weightUnit"

    var id: String { rawValue }

    /// The short label after a number: "60 kg", "135 lb".
    var symbol: String { rawValue }

    var displayName: String {
        switch self {
        case .kg: return "Kilograms (kg)"
        case .lb: return "Pounds (lb)"
        }
    }

    /// What VoiceOver reads after a number.
    var spokenName: String {
        switch self {
        case .kg: return "kilograms"
        case .lb: return "pounds"
        }
    }

    /// One tap of a weight stepper: the smallest common plate pair on a bar.
    var loadStep: Double {
        switch self {
        case .kg: return 2.5
        case .lb: return 5
        }
    }

    /// The most a weight stepper goes up to.
    var maxLoad: Double {
        switch self {
        case .kg: return 500
        case .lb: return 1100
        }
    }

    /// A first set's weight when the exercise has never been logged: an empty bar.
    var emptyBar: Double {
        switch self {
        case .kg: return 20
        case .lb: return 45
        }
    }

    var bodyWeightStep: Double {
        switch self {
        case .kg: return 0.5
        case .lb: return 1
        }
    }

    var bodyWeightRange: ClosedRange<Double> {
        switch self {
        case .kg: return 30...300
        case .lb: return 66...660
        }
    }

    /// Where the body-weight stepper starts before anything has been entered.
    var defaultBodyWeight: Double {
        switch self {
        case .kg: return 70
        case .lb: return 155
        }
    }

    /// A weight rounded to the nearest plate step, never below zero.
    func roundedToStep(_ weight: Double) -> Double {
        max(0, (weight / loadStep).rounded() * loadStep)
    }

    /// "62.5 kg".
    @MainActor
    func string(_ weight: Double) -> String {
        "\(WeightFormatter.string(weight)) \(symbol)"
    }

    // MARK: - Preference

    /// The saved preference, for code outside a view. Views read `\.weightUnit` from the
    /// environment instead, so they redraw when it changes.
    static var current: WeightUnit {
        UserDefaults.standard.string(forKey: storageKey).flatMap(WeightUnit.init(rawValue:)) ?? .kg
    }

    /// Pounds where the region measures in US customary units, kilograms everywhere else.
    static func regionDefault(for locale: Locale = .current) -> WeightUnit {
        locale.measurementSystem == .us ? .lb : .kg
    }

    /// Picks the unit from the device's region on a brand-new install. A store that already
    /// has data keeps kilograms, the only unit there was before this preference existed.
    static func chooseDefaultIfUnset(isFreshInstall: Bool, defaults: UserDefaults = .standard, locale: Locale = .current) {
        guard defaults.string(forKey: storageKey) == nil else { return }
        let unit = isFreshInstall ? regionDefault(for: locale) : .kg
        defaults.set(unit.rawValue, forKey: storageKey)
    }

    // MARK: - Conversion

    static let poundsPerKilogram = 2.204_622_621_8

    /// `value` in this unit, expressed in `other`, rounded to the one decimal the app shows.
    func convert(_ value: Double, to other: WeightUnit) -> Double {
        guard self != other else { return value }
        let converted = other == .lb ? value * Self.poundsPerKilogram : value / Self.poundsPerKilogram
        return (converted * 10).rounded() / 10
    }

    /// Rewrites every stored weight from one unit to the other: each set, the profile's body
    /// weight and the body-weight log. Returns how many sets it changed.
    @MainActor
    @discardableResult
    static func convertStoredWeights(from old: WeightUnit, to new: WeightUnit, in context: ModelContext) throws -> Int {
        guard old != new else { return 0 }
        // Read everything first, so a failed fetch can't leave some weights converted.
        let sets = try context.fetch(FetchDescriptor<SetEntry>())
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        let readings = try context.fetch(FetchDescriptor<BodyWeightEntry>())
        let original = (sets.map(\.weight), profiles.map(\.weightKg), readings.map(\.weight))

        for set in sets { set.weight = old.convert(set.weight, to: new) }
        for profile in profiles { profile.weightKg = profile.weightKg.map { old.convert($0, to: new) } }
        for reading in readings { reading.weight = old.convert(reading.weight, to: new) }
        do {
            try context.save()
        } catch {
            // The caller keeps the old unit, so the numbers must go back to it too. Put the
            // originals back by hand: converting back would round them a second time, and
            // `context.rollback()` can trap in SwiftData.
            for (set, weight) in zip(sets, original.0) { set.weight = weight }
            for (profile, weight) in zip(profiles, original.1) { profile.weightKg = weight }
            for (reading, weight) in zip(readings, original.2) { reading.weight = weight }
            throw error
        }
        return sets.count
    }
}

// MARK: - Environment

private struct WeightUnitKey: EnvironmentKey {
    static let defaultValue = WeightUnit.kg
}

extension EnvironmentValues {
    /// The user's weight unit, injected at the app root from `@AppStorage`.
    var weightUnit: WeightUnit {
        get { self[WeightUnitKey.self] }
        set { self[WeightUnitKey.self] = newValue }
    }
}
