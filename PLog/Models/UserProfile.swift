//
//  UserProfile.swift
//  PLog
//
//  The user's own details (Settings screen). A singleton in practice: exactly one row is
//  guaranteed to exist by `PLogApp` at launch — see `UserProfile.ensureExists(in:)`.
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String

    /// Left `nil` until the user has actually set it, rather than defaulting to a number
    /// that looks chosen. Settings seeds a sensible starting value on first appearance.
    var age: Int?

    var gender: Gender

    var heightCm: Double?

    var weightKg: Double?

    init(
        name: String = "",
        age: Int? = nil,
        gender: Gender = .female,
        heightCm: Double? = nil,
        weightKg: Double? = nil
    ) {
        self.name = name
        self.age = age
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
    }
}

extension UserProfile {
    /// Guarantees exactly one profile row exists. Called once at launch; cheap no-op on
    /// every subsequent launch once a profile is present.
    static func ensureExists(in context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile())
        context.saveLogged()
    }
}
